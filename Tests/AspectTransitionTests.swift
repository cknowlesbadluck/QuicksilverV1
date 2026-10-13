import Core
import Foundation
import XCTest

/// Priority 3: autonomous aspect transitions of the one entity, verified
/// deterministically with an injected clock (dwell / hysteresis behaviour).
final class AspectTransitionTests: XCTestCase {
    private let policy = AspectPolicy(minimumDwellSeconds: 600)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testDwellSuppressesAutonomousChangeInsideWindow() {
        let result = policy.preferredAspect(
            current: .quicksilver,
            lastChangedAt: start,
            intent: Intent(kind: .create),
            now: start.addingTimeInterval(599)
        )
        XCTAssertNil(result, "No autonomous change before the dwell elapses")
    }

    func testChangeAllowedOnceDwellElapses() {
        let result = policy.preferredAspect(
            current: .quicksilver,
            lastChangedAt: start,
            intent: Intent(kind: .create),
            now: start.addingTimeInterval(600)
        )
        XCTAssertEqual(result, .forge)
    }

    func testNoRecommendationWhenAlreadyInTargetAspect() {
        let result = policy.preferredAspect(
            current: .eternal,
            lastChangedAt: nil,
            intent: Intent(kind: .retrieve),
            now: start
        )
        XCTAssertNil(result, "Hysteresis: never re-recommend the current aspect")
    }

    func testEnvironmentalPressureTiltsToForge() {
        XCTAssertEqual(
            policy.preferredAspect(current: .quicksilver, lastChangedAt: nil, intent: nil, isLowPower: true, now: start),
            .forge
        )
        XCTAssertEqual(
            policy.preferredAspect(
                current: .eternal, lastChangedAt: nil, intent: nil, thermalState: "critical", now: start
            ),
            .forge
        )
    }

    func testMemoryHintsTiltToEternalWithoutStrongerSignal() {
        XCTAssertEqual(
            policy.preferredAspect(
                current: .quicksilver, lastChangedAt: nil, intent: nil, hasRecentMemoryHints: true, now: start
            ),
            .eternal
        )
    }

    func testIntentSignalOutranksEnvironment() {
        XCTAssertEqual(
            policy.preferredAspect(
                current: .quicksilver, lastChangedAt: nil, intent: Intent(kind: .observe), isLowPower: true, now: start
            ),
            .eternal
        )
    }

    func testExplicitSwitchAndUnknownStayNeutral() {
        for kind in [Intent.Kind.switchAspect, .unknown] {
            XCTAssertNil(policy.preferredAspect(current: .forge, lastChangedAt: nil, intent: Intent(kind: kind), now: start))
        }
    }

    func testTurnMappingCoversEveryIntentKind() {
        let expected: [Intent.Kind: Aspect] = [
            .create: .forge, .diagnose: .forge,
            .observe: .eternal, .retrieve: .eternal, .remember: .eternal,
            .inquire: .quicksilver, .express: .quicksilver,
            .switchAspect: .quicksilver, .unknown: .quicksilver
        ]
        XCTAssertEqual(Set(expected.keys), Set(Intent.Kind.allCases), "Every intent kind needs an expected aspect")
        for kind in Intent.Kind.allCases {
            XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: kind)), expected[kind], "\(kind)")
        }
        XCTAssertEqual(
            policy.aspectForTurn(intent: Intent(kind: .inquire), environment: .init(isLowPower: true)),
            .forge
        )
        XCTAssertEqual(
            policy.aspectForTurn(intent: Intent(kind: .remember), environment: .init(isLowPower: true)),
            .eternal
        )
    }

    /// A sequence of turns over simulated time: thrash is suppressed, and
    /// the entity settles after each dwell window.
    func testSimulatedSessionDoesNotThrash() {
        var current = Aspect.quicksilver
        var lastChange: Date?
        var changes = 0
        let kinds: [Intent.Kind] = [.create, .retrieve, .create, .observe, .inquire, .diagnose]
        for (index, kind) in kinds.enumerated() {
            let now = start.addingTimeInterval(Double(index) * 120)
            if let next = policy.preferredAspect(
                current: current, lastChangedAt: lastChange, intent: Intent(kind: kind), now: now
            ) {
                current = next
                lastChange = now
                changes += 1
            }
        }
        XCTAssertEqual(changes, 1, "Six intents in 10 minutes must cause one change, not six")
    }
}
