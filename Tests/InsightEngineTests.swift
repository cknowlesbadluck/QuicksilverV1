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

    func testNetworkInstabilityIgnoresOutdatedSignals() {
        let now = Date()
        // Signals older than 600 seconds (10 minutes)
        let recentSignals = [
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-700), value: "disconnected"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-800), value: "satisfied"),
            Signal(source: .network, category: .connectivity, timestamp: now.addingTimeInterval(-900), value: "constrained")
        ]

        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        let insight = engine.insight(for: signal, recent: recentSignals)

        XCTAssertNil(insight)
    }

    func testNetworkInstabilityIgnoresNonNetworkSignals() {
        let now = Date()
        let recentSignals = [
            Signal(source: .battery, category: .power, timestamp: now.addingTimeInterval(-100), value: "unplugged"),
            Signal(source: .storage, category: .capacity, timestamp: now.addingTimeInterval(-200), value: "low"),
            Signal(source: .device, category: .performance, timestamp: now.addingTimeInterval(-300), value: "nominal")
        ]

        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        let insight = engine.insight(for: signal, recent: recentSignals)

        XCTAssertNil(insight)
    }

    func testConstrainedOrExpensiveNetworkInsight() {
        let constrainedSignal = Signal(
            source: .network,
            category: .connectivity,
            value: "constrained"
        )
        let constrainedInsight = engine.insight(for: constrainedSignal, recent: [])

        XCTAssertNotNil(constrainedInsight)
        XCTAssertEqual(constrainedInsight?.title, "Constrained network")
        XCTAssertEqual(constrainedInsight?.body, "The current path is marked constrained. Background data may be limited.")
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
        XCTAssertEqual(expensiveInsight?.body, "The current path is marked expensive. Background data may be limited.")
    }

    func testHealthyNetworkProducesNoInsight() {
        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "satisfied"
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNil(insight)
    }

    // MARK: - Battery Insights

    func testBatteryUnmonitoredOrInvalidLevel() {
        let nilValueSignal = Signal(
            source: .battery,
            category: .power,
            value: "unknown",
            numericValue: nil
        )
        XCTAssertNil(engine.insight(for: nilValueSignal, recent: []))

        let negativeLevelSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: -1.0
        )
        XCTAssertNil(engine.insight(for: negativeLevelSignal, recent: []))
    }

    func testLowBatteryUnpluggedInsight() {
        let signal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.10
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Low battery")
        XCTAssertEqual(insight?.body, "Battery is at 10%.")
        XCTAssertEqual(insight?.severity, .warning)
        XCTAssertEqual(insight?.suggestedAction, "Connect to power or enable Low Power Mode.")
    }

    func testLowBatteryChargingProducesNoLowBatteryInsight() {
        let signal = Signal(
            source: .battery,
            category: .power,
            value: "charging",
            numericValue: 0.10
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNil(insight)
    }

    func testBatteryElevatedDrainInsight() {
        let previousSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.85
        )
        let currentSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.75 // Drop of 0.10 (> 0.08 threshold)
        )

        let insight = engine.insight(for: currentSignal, recent: [previousSignal])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Elevated drain")
        XCTAssertEqual(insight?.body, "Battery dropped faster than usual in the recent window.")
        XCTAssertEqual(insight?.severity, .notice)
        XCTAssertEqual(insight?.suggestedAction, "Review recently used apps or background activity.")
    }

    func testBatteryNormalDrainProducesNoInsight() {
        let previousSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.85
        )
        let currentSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.80 // Drop of 0.05 (<= 0.08 threshold)
        )

        let insight = engine.insight(for: currentSignal, recent: [previousSignal])

        XCTAssertNil(insight)
    }

    func testBatteryElevatedDrainIgnoresNegativePreviousLevel() {
        let previousSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: -1.0
        )
        let currentSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.50
        )

        let insight = engine.insight(for: currentSignal, recent: [previousSignal])

        XCTAssertNil(insight)
    }

    func testBatteryElevatedDrainIgnoresSameSignalID() {
        let currentSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.50
        )

        // Passing the same signal in recent
        let insight = engine.insight(for: currentSignal, recent: [currentSignal])

        XCTAssertNil(insight)
    }

    // MARK: - Storage Insights

    func testStorageSufficientProducesNoInsight() {
        let signal = Signal(
            source: .storage,
            category: .capacity,
            value: "normal",
            numericValue: 12.0
        )

        XCTAssertNil(engine.insight(for: signal, recent: []))
    }

    func testStorageNilNumericValueProducesNoInsight() {
        let signal = Signal(
            source: .storage,
            category: .capacity,
            value: "normal",
            numericValue: nil
        )

        XCTAssertNil(engine.insight(for: signal, recent: []))
    }

    func testStoragePressureNoticeSeverity() {
        let signal = Signal(
            source: .storage,
            category: .capacity,
            value: "low",
            numericValue: 3.5
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Storage pressure")
        XCTAssertEqual(insight?.body, "Only 3.5 GB free.")
        XCTAssertEqual(insight?.severity, .notice)
        XCTAssertEqual(insight?.suggestedAction, "Offload unused apps or clear large downloads.")
    }

    func testStoragePressureWarningSeverity() {
        let signal = Signal(
            source: .storage,
            category: .capacity,
            value: "low",
            numericValue: 1.2
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Storage pressure")
        XCTAssertEqual(insight?.body, "Only 1.2 GB free.")
        XCTAssertEqual(insight?.severity, .warning)
        XCTAssertEqual(insight?.suggestedAction, "Offload unused apps or clear large downloads.")
    }

    // MARK: - Device Thermal Insights

    func testDeviceThermalCriticalInsight() {
        let signal = Signal(
            source: .device,
            category: .performance,
            value: "critical"
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Thermal pressure")
        XCTAssertEqual(insight?.body, "Device is under elevated thermal load (critical).")
        XCTAssertEqual(insight?.severity, .warning)
        XCTAssertEqual(insight?.suggestedAction, "Reduce workload or move to a cooler environment.")
    }

    func testDeviceThermalSeriousInsight() {
        let signal = Signal(
            source: .device,
            category: .performance,
            value: "serious_thermal_state"
        )

        let insight = engine.insight(for: signal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Thermal pressure")
        XCTAssertEqual(insight?.body, "Device is under elevated thermal load (serious_thermal_state).")
        XCTAssertEqual(insight?.severity, .warning)
    }

    func testDeviceThermalNominalProducesNoInsight() {
        let signal = Signal(
            source: .device,
            category: .performance,
            value: "nominal"
        )

        XCTAssertNil(engine.insight(for: signal, recent: []))
    }

    // MARK: - Unhandled Signal Sources

    func testUnhandledSignalSourcesReturnNil() {
        let sources: [Signal.Source] = [.lifecycle, .user, .system]

        for source in sources {
            let signal = Signal(
                source: source,
                category: .diagnostic,
                value: "some_event"
            )
            XCTAssertNil(engine.insight(for: signal, recent: []), "Expected nil insight for source \(source)")
        }
    }

    // MARK: - Persona Tag Traceability

    func testPersonaTagTraceabilityDoesNotAlterInsightBodyOrTitle() {
        let signal = Signal(
            source: .network,
            category: .connectivity,
            value: "disconnected"
        )

        let quicksilverInsight = engine.insight(for: signal, recent: [], personaID: "quicksilver")
        let forgeInsight = engine.insight(for: signal, recent: [], personaID: "forge")
        let eternalInsight = engine.insight(for: signal, recent: [], personaID: "eternal")
        let defaultInsight = engine.insight(for: signal, recent: [])

        XCTAssertEqual(quicksilverInsight?.personaStyle, "quicksilver")
        XCTAssertEqual(forgeInsight?.personaStyle, "forge")
        XCTAssertEqual(eternalInsight?.personaStyle, "eternal")
        XCTAssertEqual(defaultInsight?.personaStyle, "")

        // Verify architecture rule: engine is persona-agnostic. Title & body match across personas.
        XCTAssertEqual(quicksilverInsight?.title, forgeInsight?.title)
        XCTAssertEqual(quicksilverInsight?.body, forgeInsight?.body)
        XCTAssertEqual(forgeInsight?.title, eternalInsight?.title)
        XCTAssertEqual(forgeInsight?.body, eternalInsight?.body)
        XCTAssertEqual(eternalInsight?.title, defaultInsight?.title)
        XCTAssertEqual(eternalInsight?.body, defaultInsight?.body)
    }
}
