import XCTest
@testable import Core
@testable import Nexus

final class InsightEngineBatteryTests: XCTestCase {

    private var engine: InsightEngine!

    override func setUp() {
        super.setUp()
        engine = InsightEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

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

    func testLowBatteryInsight() {
        let unpluggedSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.10
        )

        let insight = engine.insight(for: unpluggedSignal, recent: [])

        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Low battery")
        XCTAssertEqual(insight?.body, "Battery is at 10%.")
        XCTAssertEqual(insight?.severity, .warning)

        let chargingSignal = Signal(
            source: .battery,
            category: .power,
            value: "charging",
            numericValue: 0.10
        )

        XCTAssertNil(engine.insight(for: chargingSignal, recent: []))
    }

    func testBatteryElevatedDrainAndNormalDrain() {
        let previousSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.85
        )

        let currentElevatedSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.75
        )

        let elevatedInsight = engine.insight(for: currentElevatedSignal, recent: [previousSignal])

        XCTAssertNotNil(elevatedInsight)
        XCTAssertEqual(elevatedInsight?.title, "Elevated drain")

        let currentNormalSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: 0.80
        )

        XCTAssertNil(engine.insight(for: currentNormalSignal, recent: [previousSignal]))

        let negativePreviousSignal = Signal(
            source: .battery,
            category: .power,
            value: "unplugged",
            numericValue: -1.0
        )

        XCTAssertNil(engine.insight(for: currentElevatedSignal, recent: [negativePreviousSignal]))
        XCTAssertNil(engine.insight(for: currentElevatedSignal, recent: [currentElevatedSignal]))
    }
}
