import XCTest
@testable import Quicksilver

final class MotionPolicyTests: XCTestCase {
    func testReduceMotionCollapsesRepeatingOrbitToCrossFade() {
        let resolved = MotionTokens.resolved(MotionTokens.celestialOrbit, reduceMotion: true)
        XCTAssertEqual(resolved, MotionTokens.reduced(MotionTokens.celestialOrbit))
    }

    func testFullMotionKeepsStabilizationSpring() {
        let resolved = MotionTokens.resolved(MotionTokens.stabilization, reduceMotion: false)
        XCTAssertEqual(resolved, MotionTokens.stabilization)
    }

    func testRealmTransitionHonorsTheSamePolicy() {
        XCTAssertEqual(
            RealmTransition.animation(reduceMotion: true),
            MotionTokens.resolved(MotionTokens.realmTransition, reduceMotion: true)
        )
        XCTAssertEqual(
            RealmTransition.animation(reduceMotion: false),
            MotionTokens.resolved(MotionTokens.realmTransition, reduceMotion: false)
        )
    }
}
