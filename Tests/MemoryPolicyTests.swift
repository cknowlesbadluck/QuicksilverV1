import XCTest
@testable import Personas

/// Aspect memory policy: pure values the Brain and Memory screen read. Previously untested.
final class MemoryPolicyTests: XCTestCase {
    func testInitClampsToUnitInterval() {
        let policy = MemoryPolicy(retentionThreshold: 1.7, writeImportanceHint: -0.2)
        XCTAssertEqual(policy.retentionThreshold, 1)
        XCTAssertEqual(policy.writeImportanceHint, 0)
        XCTAssertEqual(MemoryPolicy(retentionThreshold: -3).retentionThreshold, 0)
    }

    func testDefaultsLeaveWriteHintUnset() {
        let policy = MemoryPolicy()
        XCTAssertEqual(policy.retentionThreshold, 0.4)
        XCTAssertTrue(policy.prefersScopedView)
        XCTAssertNil(policy.writeImportanceHint)
    }

    func testAspectLookup() {
        XCTAssertEqual(MemoryPolicy.policy(for: "forge").retentionThreshold, MemoryPolicy.forge.retentionThreshold)
        XCTAssertEqual(MemoryPolicy.policy(for: "eternal").retentionThreshold, MemoryPolicy.eternal.retentionThreshold)
        XCTAssertEqual(MemoryPolicy.policy(for: "quicksilver").retentionThreshold, MemoryPolicy.quicksilver.retentionThreshold)
    }

    /// An unknown or empty aspect tag falls back to the core entity, never to a scoped realm.
    func testUnknownAspectFallsBackToQuicksilver() {
        for tag in ["", "FORGE", "unknown", "eternal "] {
            let policy = MemoryPolicy.policy(for: tag)
            XCTAssertEqual(policy.retentionThreshold, MemoryPolicy.quicksilver.retentionThreshold, tag)
            XCTAssertFalse(policy.prefersScopedView, tag)
        }
    }

    /// Eternal is the continuity aspect: it shows the most memory and weights its writes highest.
    func testEternalRetainsMostAndForgeIsMostSelective() {
        XCTAssertLessThan(MemoryPolicy.eternal.retentionThreshold, MemoryPolicy.quicksilver.retentionThreshold)
        XCTAssertLessThan(MemoryPolicy.quicksilver.retentionThreshold, MemoryPolicy.forge.retentionThreshold)
        let hints = [MemoryPolicy.forge, .quicksilver, .eternal].compactMap(\.writeImportanceHint)
        XCTAssertEqual(hints.count, 3, "every built-in aspect sets a write hint")
        XCTAssertEqual(hints.max(), MemoryPolicy.eternal.writeImportanceHint)
    }

    /// Entity-wide memory: only Forge scopes its view; the core and Eternal see shared memory.
    func testOnlyForgeScopesItsView() {
        XCTAssertTrue(MemoryPolicy.forge.prefersScopedView)
        XCTAssertFalse(MemoryPolicy.quicksilver.prefersScopedView)
        XCTAssertFalse(MemoryPolicy.eternal.prefersScopedView)
    }

    func testBuiltInsAreWithinUnitInterval() {
        for policy in [MemoryPolicy.forge, .quicksilver, .eternal] {
            XCTAssertTrue((0...1).contains(policy.retentionThreshold))
            XCTAssertTrue((0...1).contains(policy.writeImportanceHint ?? 0))
        }
    }
}
