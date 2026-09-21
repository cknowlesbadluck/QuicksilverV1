import XCTest
@testable import Core
@testable import Nexus

@MainActor
final class SignalPipelineTests: XCTestCase {

    private var logger: LoggerService!
    private var bus: EventBus!
    private var pipeline: SignalPipeline!

    override func setUp() async throws {
        try await super.setUp()
        logger = LoggerService()
        bus = EventBus()
        pipeline = SignalPipeline(eventBus: bus, logger: logger, dedupeInterval: 0.2)
    }

    override func tearDown() async throws {
        pipeline = nil
        bus = nil
        logger = nil
        try await super.tearDown()
    }

    // MARK: - Basic Ingestion and General Event Publishing

    func testIngestPublishesSignalReceivedEvent() async {
        let expectation = XCTestExpectation(description: "signalReceived event published")
        nonisolated(unsafe) var receivedSource: String?
        nonisolated(unsafe) var receivedValue: String?
        nonisolated(unsafe) var receivedNumericValue: Double?

        _ = await bus.subscribe { event in
            if case .signalReceived(let source, let value, let numericValue) = event {
                receivedSource = source
                receivedValue = value
                receivedNumericValue = numericValue
                expectation.fulfill()
            }
        }

        let signal = Signal(source: .storage, category: .capacity, value: "sufficient", numericValue: 42.0)
        pipeline.ingest(signal)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(receivedSource, Signal.Source.storage.rawValue)
        XCTAssertEqual(receivedValue, "sufficient")
        XCTAssertEqual(receivedNumericValue, 42.0)
    }

    // MARK: - Rate Limiting / Deduplication

    func testDeduplicationSuppressesDuplicateSignalsWithinInterval() async {
        nonisolated(unsafe) var signalCount = 0
        let expectation = XCTestExpectation(description: "First signal received")

        _ = await bus.subscribe { event in
            if case .signalReceived = event {
                signalCount += 1
                if signalCount == 1 {
                    expectation.fulfill()
                }
            }
        }

        let signal = Signal(source: .storage, category: .capacity, value: "sufficient", numericValue: 10.0)

        // First ingest emits event
        pipeline.ingest(signal)
        await fulfillment(of: [expectation], timeout: 2.0)

        // Second ingest immediately with same source & value should be deduped
        pipeline.ingest(signal)

        // Give async tasks time to execute if any were spawned
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(signalCount, 1, "Duplicate signal within dedupeInterval should be suppressed")
    }

    func testDeduplicationAllowsSignalAfterValueChanges() async {
        nonisolated(unsafe) var receivedValues: [String] = []
        let expectation = XCTestExpectation(description: "Two distinct signals received")
        expectation.expectedFulfillmentCount = 2

        _ = await bus.subscribe { event in
            if case .signalReceived(_, let value, _) = event {
                receivedValues.append(value)
                expectation.fulfill()
            }
        }

        let signal1 = Signal(source: .storage, category: .capacity, value: "normal", numericValue: 10.0)
        let signal2 = Signal(source: .storage, category: .capacity, value: "low", numericValue: 2.0)

        pipeline.ingest(signal1)
        pipeline.ingest(signal2)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(receivedValues, ["normal", "low"])
    }

    func testDeduplicationAllowsSignalAfterDedupeIntervalPasses() async {
        nonisolated(unsafe) var signalCount = 0
        let expectation = XCTestExpectation(description: "Two signals received after delay")
        expectation.expectedFulfillmentCount = 2

        _ = await bus.subscribe { event in
            if case .signalReceived = event {
                signalCount += 1
                expectation.fulfill()
            }
        }

        let signal = Signal(source: .storage, category: .capacity, value: "sufficient", numericValue: 10.0)

        pipeline.ingest(signal)

        // Wait longer than dedupeInterval (0.2s)
        try? await Task.sleep(for: .milliseconds(300))

        pipeline.ingest(signal)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(signalCount, 2, "Signal should be processed after dedupeInterval elapses")
    }

    // MARK: - Autonomy Event Mapping

    func testBatterySignalMapping() async {
        let expectationSignal = XCTestExpectation(description: "signalReceived event")
        let expectationBattery = XCTestExpectation(description: "batteryPressureChanged event")

        nonisolated(unsafe) var batteryLevel: Double?
        nonisolated(unsafe) var isLowPower: Bool?

        _ = await bus.subscribe { event in
            switch event {
            case .signalReceived:
                expectationSignal.fulfill()
            case .batteryPressureChanged(let level, let lowPower):
                batteryLevel = level
                isLowPower = lowPower
                expectationBattery.fulfill()
            default:
                break
            }
        }

        let signal = Signal(source: .battery, category: .power, value: "unplugged", numericValue: 0.15)
        pipeline.ingest(signal)

        await fulfillment(of: [expectationSignal, expectationBattery], timeout: 2.0)

        XCTAssertEqual(batteryLevel, 0.15)
        XCTAssertEqual(isLowPower, true, "Battery level < 0.20 should mark isLowPower as true")
    }

    func testDeviceThermalAndLowPowerSignalMapping() async {
        let expectationThermal = XCTestExpectation(description: "thermalPressureChanged event")
        let expectationBattery = XCTestExpectation(description: "batteryPressureChanged event")

        nonisolated(unsafe) var thermalState: String?
        nonisolated(unsafe) var batteryLevel: Double?
        nonisolated(unsafe) var isLowPower: Bool?

        _ = await bus.subscribe { event in
            switch event {
            case .thermalPressureChanged(let state):
                thermalState = state
                expectationThermal.fulfill()
            case .batteryPressureChanged(let level, let lowPower):
                batteryLevel = level
                isLowPower = lowPower
                expectationBattery.fulfill()
            default:
                break
            }
        }

        let signal = Signal(
            source: .device,
            category: .performance,
            value: "serious",
            numericValue: nil,
            metadata: ["lowPower": "true"]
        )
        pipeline.ingest(signal)

        await fulfillment(of: [expectationThermal, expectationBattery], timeout: 2.0)

        XCTAssertEqual(thermalState, "serious")
        XCTAssertEqual(batteryLevel, 0.15, "Default fallback level when numericValue is nil should be 0.15")
        XCTAssertEqual(isLowPower, true)
    }

    func testNetworkSignalMapping() async {
        let expectation = XCTestExpectation(description: "networkConditionChanged event")

        nonisolated(unsafe) var connected: Bool?
        nonisolated(unsafe) var constrained: Bool?

        _ = await bus.subscribe { event in
            if case .networkConditionChanged(let isConnected, let isConstrained) = event {
                connected = isConnected
                constrained = isConstrained
                expectation.fulfill()
            }
        }

        let signal = Signal(source: .network, category: .connectivity, value: "constrained")
        pipeline.ingest(signal)

        await fulfillment(of: [expectation], timeout: 2.0)

        XCTAssertEqual(connected, true)
        XCTAssertEqual(constrained, true)
    }
}
