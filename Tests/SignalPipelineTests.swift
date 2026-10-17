import Synchronization
import XCTest
@testable import Core
@testable import Nexus

/// Nexus ingress (Sense): dedupe and the mapping onto the autonomy events that PersonaManager
/// and the Brain react to. Previously untested.
@MainActor
final class SignalPipelineTests: XCTestCase {
    private final class Recorder: Sendable {
        private let storage = Mutex<[EventBus.Event]>([])
        func append(_ event: EventBus.Event) { storage.withLock { $0.append(event) } }
        var events: [EventBus.Event] { storage.withLock { $0 } }
    }

    private var bus: EventBus!
    private var recorder: Recorder!

    override func setUp() async throws {
        bus = EventBus()
        let recorder = Recorder()
        self.recorder = recorder
        _ = await bus.subscribe { recorder.append($0) }
    }

    override func tearDown() async throws {
        bus = nil
        recorder = nil
    }

    private func pipeline(dedupe: TimeInterval = 2.0) -> SignalPipeline {
        SignalPipeline(eventBus: bus, logger: LoggerService(), dedupeInterval: dedupe)
    }

    /// Waits until at least `count` events arrive, then a short settle window to catch extras.
    private func events(atLeast count: Int, settle: TimeInterval = 0.3) async -> [EventBus.Event] {
        let deadline = Date().addingTimeInterval(3)
        while recorder.events.count < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        try? await Task.sleep(nanoseconds: UInt64(settle * 1_000_000_000))
        return recorder.events
    }

    private func signals(_ events: [EventBus.Event]) -> [String] {
        events.compactMap {
            if case .signalReceived(let source, let value, _) = $0 { return "\(source)=\(value)" }
            return nil
        }
    }

    private func battery(_ events: [EventBus.Event]) -> [(Double, Bool)] {
        events.compactMap {
            if case .batteryPressureChanged(let level, let low) = $0 { return (level, low) }
            return nil
        }
    }

    private func network(_ events: [EventBus.Event]) -> [(Bool, Bool)] {
        events.compactMap {
            if case .networkConditionChanged(let connected, let constrained) = $0 { return (connected, constrained) }
            return nil
        }
    }

    func testLowBatteryPublishesSignalAndPressure() async {
        pipeline().ingest(Signal(source: .battery, category: .power, value: "15%", numericValue: 0.15))
        let all = await events(atLeast: 2)
        XCTAssertEqual(signals(all), ["battery=15%"])
        XCTAssertEqual(battery(all).count, 1)
        XCTAssertEqual(battery(all).first?.0, 0.15)
        XCTAssertEqual(battery(all).first?.1, true)
    }

    func testHealthyBatteryIsNotLowPower() async {
        pipeline().ingest(Signal(source: .battery, category: .power, value: "80%", numericValue: 0.8))
        let all = await events(atLeast: 2)
        XCTAssertEqual(battery(all).first?.1, false)
    }

    func testUnknownBatteryLevelIsNotLowUnlessLabelled() async {
        let pipe = pipeline(dedupe: 0)
        pipe.ingest(Signal(source: .battery, category: .power, value: "unknown"))
        let first = await events(atLeast: 2)
        XCTAssertEqual(battery(first).first?.0, -1)
        XCTAssertEqual(battery(first).first?.1, false)
        pipe.ingest(Signal(source: .battery, category: .power, value: "Low"))
        let all = await events(atLeast: 4)
        XCTAssertEqual(battery(all).last?.1, true)
    }

    func testDeviceLowPowerMetadataRaisesBatteryPressure() async {
        pipeline().ingest(
            Signal(source: .device, category: .performance, value: "nominal", metadata: ["lowPowerMode": "true"])
        )
        let all = await events(atLeast: 3)
        XCTAssertTrue(all.contains {
            if case .thermalPressureChanged(let state) = $0 { return state == "nominal" }
            return false
        })
        XCTAssertEqual(battery(all).first?.1, true)
    }

    func testDeviceWithoutLowPowerOnlyReportsThermal() async {
        pipeline().ingest(Signal(source: .device, category: .performance, value: "serious"))
        let all = await events(atLeast: 2)
        XCTAssertTrue(battery(all).isEmpty)
    }

    func testNetworkStatesMapToConnectivity() async {
        let pipe = pipeline(dedupe: 0)
        pipe.ingest(Signal(source: .network, category: .connectivity, value: "disconnected"))
        _ = await events(atLeast: 2)
        pipe.ingest(Signal(source: .network, category: .connectivity, value: "expensive"))
        _ = await events(atLeast: 4)
        pipe.ingest(Signal(source: .network, category: .connectivity, value: "wifi"))
        let all = await events(atLeast: 6)
        let mapped = network(all)
        XCTAssertEqual(mapped.map(\.0), [false, true, true])
        XCTAssertEqual(mapped.map(\.1), [false, true, false])
    }

    func testIdenticalSignalsAreDedupedWithinInterval() async {
        let pipe = pipeline(dedupe: 60)
        pipe.ingest(Signal(source: .storage, category: .capacity, value: "ok"))
        pipe.ingest(Signal(source: .storage, category: .capacity, value: "ok"))
        let all = await events(atLeast: 1)
        XCTAssertEqual(signals(all), ["storage=ok"])
    }

    func testChangedValueIsNotDeduped() async {
        let pipe = pipeline(dedupe: 60)
        pipe.ingest(Signal(source: .storage, category: .capacity, value: "ok"))
        pipe.ingest(Signal(source: .storage, category: .capacity, value: "low"))
        let all = await events(atLeast: 2)
        XCTAssertEqual(Set(signals(all)), ["storage=ok", "storage=low"])
    }

    func testDedupeIsPerSource() async {
        let pipe = pipeline(dedupe: 60)
        pipe.ingest(Signal(source: .storage, category: .capacity, value: "ok"))
        pipe.ingest(Signal(source: .system, category: .diagnostic, value: "ok"))
        let all = await events(atLeast: 2)
        XCTAssertEqual(Set(signals(all)), ["storage=ok", "system=ok"])
    }

    func testUnmappedSourcesPublishOnlyTheUnifiedSignal() async {
        pipeline().ingest(Signal(source: .storage, category: .capacity, value: "ok"))
        let all = await events(atLeast: 1)
        XCTAssertEqual(all.count, 1)
    }
}
