import Core
import Foundation
import XCTest

/// Priority 3: the Brain's projection gate and relaunch continuity.
final class AspectContinuityTests: XCTestCase {
    private let policy = AspectPolicy(minimumDwellSeconds: 900, turnDwellSeconds: 90)
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstProjectionIsAllowed() {
        XCTAssertTrue(policy.shouldProject(.forge, current: .quicksilver, lastChangedAt: nil, now: start))
    }

    func testDwellSuppressionMeansStayNotNoObjection() {
        XCTAssertFalse(policy.shouldProject(
            .eternal, current: .forge, lastChangedAt: start, now: start.addingTimeInterval(89)
        ))
        XCTAssertTrue(policy.shouldProject(
            .eternal, current: .forge, lastChangedAt: start, now: start.addingTimeInterval(90)
        ))
    }

    func testForceOverridesDwellButNeverReprojectsCurrent() {
        XCTAssertTrue(policy.shouldProject(.eternal, current: .forge, lastChangedAt: start, force: true, now: start))
        XCTAssertFalse(policy.shouldProject(.forge, current: .forge, lastChangedAt: nil, force: true, now: start))
        XCTAssertFalse(policy.shouldProject(.forge, current: .forge, lastChangedAt: nil, now: start))
    }

    func testBackwardsClockDoesNotLockTheEntity() {
        XCTAssertTrue(policy.shouldProject(
            .eternal, current: .forge, lastChangedAt: start, now: start.addingTimeInterval(-3_600)
        ))
    }

    func testContinuityStoreRoundTripsAndClears() throws {
        let suite = "AspectContinuityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AspectContinuityStore(defaults: defaults)

        XCTAssertNil(store.load())
        store.save(.eternal, changedAt: start)
        XCTAssertEqual(store.load(), .init(aspect: .eternal, lastChangedAt: start))

        // A relaunch is a new store over the same defaults.
        XCTAssertEqual(AspectContinuityStore(defaults: defaults).load()?.aspect, .eternal)

        store.clear()
        XCTAssertNil(store.load())
    }

    func testCorruptStoredAspectIsIgnored() throws {
        let suite = "AspectContinuityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("loki-mode", forKey: "mercury.aspect.active")
        XCTAssertNil(AspectContinuityStore(defaults: defaults).load())
    }
}
