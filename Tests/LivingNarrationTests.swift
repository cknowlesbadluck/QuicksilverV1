import XCTest
@testable import Personas

/// P-T6: LivingNarration never speaks as a separate aspect; intent replies have no `[…]` prefix.
final class LivingNarrationTests: XCTestCase {

    private let bannedStarters = ["Forge", "Eternal", "Quicksilver"]

    private func assertNoAspectSpeaker(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        for name in bannedStarters {
            XCTAssertFalse(
                text.hasPrefix(name),
                "LivingNarration must not start with aspect speaker '\(name)': \(text)",
                file: file,
                line: line
            )
            XCTAssertFalse(
                text.hasPrefix("\(name):"),
                "LivingNarration must not use '\(name):' label: \(text)",
                file: file,
                line: line
            )
        }
    }

    func testDefaultStatusIsFirstPersonMercury() {
        XCTAssertEqual(LivingNarration.defaultStatus, "Mercury is here. Restless, as ever.")
        assertNoAspectSpeaker(LivingNarration.defaultStatus)
    }

    func testPresentStatusNeverStartsWithAspectName() {
        struct Case {
            let insight: String?
            let health: Int
            let lowPower: Bool
        }
        let cases = [
            Case(insight: nil, health: 100, lowPower: false),
            Case(insight: nil, health: 40, lowPower: false),
            Case(insight: nil, health: 80, lowPower: true),
            Case(insight: "Thermal pressure rising", health: 90, lowPower: false),
            Case(insight: "Battery tip", health: 30, lowPower: true)
        ]
        for item in cases {
            let reading = LivingNarration.reading(
                insightTitle: item.insight,
                healthScore: item.health,
                lowPowerMode: item.lowPower
            )
            assertNoAspectSpeaker(reading.text)
            XCTAssertFalse(reading.text.hasPrefix("["), "no bracket prefix: \(reading.text)")
        }
    }

    func testCalmReadingMatchesBible() {
        let reading = LivingNarration.reading(insightTitle: nil, healthScore: 100, lowPowerMode: false)
        XCTAssertEqual(reading.text, "The Sanctum holds. I'm listening.")
        XCTAssertNil(reading.nudge)
        XCTAssertNil(reading.insightTitle)
    }

    func testPressureReadingNudgesSkepticismWithoutLabel() {
        let reading = LivingNarration.reading(insightTitle: nil, healthScore: 42, lowPowerMode: false)
        XCTAssertEqual(reading.text, "I watch rising pressure. Health 42.")
        XCTAssertEqual(reading.nudge?.dimension, .skepticism)
        XCTAssertEqual(reading.nudge?.amount, 0.04)
        assertNoAspectSpeaker(reading.text)
    }

    func testLowPowerReadingNudgesPatienceWithoutLabel() {
        let reading = LivingNarration.reading(insightTitle: nil, healthScore: 90, lowPowerMode: true)
        XCTAssertEqual(reading.text, "I note low power. Conserving.")
        XCTAssertEqual(reading.nudge?.dimension, .patience)
        assertNoAspectSpeaker(reading.text)
    }

    func testInsightReadingIsTitleOnly() {
        let reading = LivingNarration.reading(
            insightTitle: "Something worth keeping",
            healthScore: 10,
            lowPowerMode: true
        )
        XCTAssertEqual(reading.text, "Something worth keeping")
        XCTAssertEqual(reading.insightTitle, "Something worth keeping")
        XCTAssertNil(reading.nudge)
        assertNoAspectSpeaker(reading.text)
    }

    func testIntentAnswerHasNoBracketPrefix() {
        let raw = "Use an actor for the Keychain."
        let presented = LivingNarration.presentIntentAnswer(raw)
        XCTAssertEqual(presented, raw)
        XCTAssertFalse(presented.hasPrefix("["))
        XCTAssertFalse(presented.hasPrefix("[Forge]"))
        XCTAssertFalse(presented.hasPrefix("[Eternal]"))
        XCTAssertFalse(presented.hasPrefix("[Quicksilver]"))
    }

    func testIntentsSourceHasNoDisplayNameBracketPrefix() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Intents/QuicksilverIntents.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            source.contains("[\\("),
            "QuicksilverIntents must not interpolate a [displayName] prefix"
        )
        XCTAssertFalse(source.contains("[Forge]"))
        XCTAssertFalse(source.contains("[Eternal]"))
        XCTAssertFalse(source.contains("[Quicksilver]"))
        XCTAssertTrue(
            source.contains("LivingNarration.presentIntentAnswer"),
            "QueryNexusIntent should route ask results through LivingNarration.presentIntentAnswer"
        )
    }
}
