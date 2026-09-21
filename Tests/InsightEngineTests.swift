import XCTest
@testable import Core
@testable import Nexus

final class InsightEngineTests: XCTestCase {

    private var engine: InsightEngine!

    override func setUp() {
        super.setUp()
        engine = InsightEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - Network Insights

    func testNetworkDisconnectedInsight() {
        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "disconnected"
        )

        let insight = engine.insight(for: signal, recent: [], personaID: "quicksilver")

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Network lost")
        XCTAssertEqual(insight?.body, "The device is currently offline.")
        XCTAssertEqual(insight?.severity, .warning)
        XCTAssertEqual(insight?.personaStyle, "quicksilver")
        XCTAssertEqual(insight?.suggestedAction, "Check Wi-Fi or cellular settings.")
        XCTAssertEqual(insight?.relatedSignalIDs, [signal.id])
    }

    func testNetworkInstabilityInsightWithinTimeWindow() {
        let now = Date()
        let recentSignals = [
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-100), value: "disconnected"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-200), value: "satisfied"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-300), value: "constrained")
        ]

        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        let insight = engine.insight(for: signal, recent: recentSignals)

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Network instability")
        XCTAssertEqual(insight?.body, "Connection state changed 3 times in the last 10 minutes.")
        XCTAssertEqual(insight?.severity, .notice)
        XCTAssertEqual(insight?.suggestedAction, "Consider moving closer to the access point or toggling Airplane Mode.")
    }

    func testNetworkInstabilityIgnoresOutdatedOrNonNetworkSignals() {
        let now = Date()
        let outdatedSignals = [
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-700), value: "disconnected"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-800), value: "satisfied"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-900), value: "constrained")
        ]

        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        XCTAssertNil(engine.insight(for: signal, recent: outdatedSignals))

        let nonNetworkSignals = [
            Signal(source: .battery, category: .power, timestamp: now.addingTimeInterval(-100), value: "unplugged"),
            Signal(source: .storage, category: .capacity, timestamp: now.addingTimeInterval(-200), value: "low"),
            Signal(source: .device, category: .performance, timestamp: now.addingTimeInterval(-300), value: "nominal")
        ]

        XCTAssertNil(engine.insight(for: signal, recent: nonNetworkSignals))
    }

    func testConstrainedOrExpensiveAndHealthyNetworkInsight() {
        let constrainedSignal = Signal(
            source: .network,
            category: .connectivity,
            value: "constrained"
        )
        let constrainedInsight = engine.insight(for: constrainedSignal, recent: [])

        XCTAssertNotNil(constrainedInsight)
        XCTAssertEqual(constrainedInsight?.title, "Constrained network")
        XCTAssertEqual(constrainedInsight?.severity, .notice)
        XCTAssertNil(constrainedInsight?.suggestedAction)

        let expensiveSignal = Signal(
            source: .network,
            category: .connectivity,
            value: "expensive"
        )
        let expensiveInsight = engine.insight(for: expensiveSignal, recent: [])

        XCTAssertNotNil(expensiveInsight)
        XCTAssertEqual(expensiveInsight?.title, "Constrained network")

        let satisfiedSignal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        XCTAssertNil(engine.insight(for: satisfiedSignal, recent: []))
    }

    // MARK: - Storage Insights

    func testStoragePressureInsights() {
        let normalSignal = Signal(
            source: .storage,
            category: .capacity,
            value: "normal",
            numericValue: 12.0
        )
        XCTAssertNil(engine.insight(for: normalSignal, recent: []))

        let nilValueSignal = Signal(
            source: .storage,
            category: .capacity,
            value: "normal",
            numericValue: nil
        )
        XCTAssertNil(engine.insight(for: nilValueSignal, recent: []))

        let noticeSignal = Signal(
            source: .storage,
            category: .capacity,
            value: "low",
            numericValue: 3.5
        )
        let noticeInsight = engine.insight(for: noticeSignal, recent: [])

        XCTAssertNotNil(noticeInsight)
        XCTAssertEqual(noticeInsight?.title, "Storage pressure")
        XCTAssertEqual(noticeInsight?.body, "Only 3.5 GB free.")
        XCTAssertEqual(noticeInsight?.severity, .notice)

        let warningSignal = Signal(
            source: .storage,
            category: .capacity,
            value: "low",
            numericValue: 1.2
        )
        let warningInsight = engine.insight(for: warningSignal, recent: [])

        XCTAssertNotNil(warningInsight)
        XCTAssertEqual(warningInsight?.severity, .warning)
    }

    // MARK: - Device & Unhandled & Persona

    func testDeviceThermalAndUnhandledAndPersona() {
        let criticalSignal = Signal(
            source: .device,
            category: .performance,
            value: "critical"
        )
        let criticalInsight = engine.insight(for: criticalSignal, recent: [])

        XCTAssertNotNil(criticalInsight)
        XCTAssertEqual(criticalInsight?.title, "Thermal pressure")
        XCTAssertEqual(criticalInsight?.severity, .warning)

        let nominalSignal = Signal(
            source: .device,
            category: .performance,
            value: "nominal"
        )
        XCTAssertNil(engine.insight(for: nominalSignal, recent: []))

        let unhandledSources: [Signal.Source] = [.lifecycle, .user, .system]
        for source in unhandledSources {
            let signal = Signal(
                source: source,
                category: .diagnostic,
                value: "some_event"
            )
            XCTAssertNil(engine.insight(for: signal, recent: []))
        }

        let disconnectSignal = Signal(
            source: .network,
            category: .connectivity,
            value: "disconnected"
        )
        let quicksilverInsight = engine.insight(for: disconnectSignal, recent: [], personaID: "quicksilver")
        let forgeInsight = engine.insight(for: disconnectSignal, recent: [], personaID: "forge")

        XCTAssertEqual(quicksilverInsight?.personaStyle, "quicksilver")
        XCTAssertEqual(forgeInsight?.personaStyle, "forge")
        XCTAssertEqual(quicksilverInsight?.body, forgeInsight?.body)
    }
}
