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

/// Energy-aware ambient cadence: decorative TimelineViews slow in Low Power Mode and under
/// thermal pressure, and stop at critical. Measured as frame intervals (fps = 1 / interval).
final class AmbientCadenceTests: XCTestCase {
    private let full = MotionTokens.ambientFrameInterval

    func testNormalDeviceKeepsFullLife() {
        XCTAssertEqual(MotionTokens.ambientInterval(full, energy: .normal), full)
        XCTAssertEqual(MotionTokens.ambientInterval(full, energy: AmbientEnergy(thermal: .fair)), full)
        XCTAssertFalse(MotionTokens.ambientPaused(.normal))
    }

    func testLowPowerCutsDecorativeFramesByTwoThirds() {
        let interval = MotionTokens.ambientInterval(full, energy: AmbientEnergy(lowPower: true))
        XCTAssertEqual(interval, MotionTokens.conservingFrameInterval)
        XCTAssertEqual((1 / interval).rounded(), 10)   // 30 fps -> 10 fps
        XCTAssertFalse(MotionTokens.ambientPaused(AmbientEnergy(lowPower: true)))
    }

    func testSeriousThermalConservesAndCriticalPauses() {
        XCTAssertEqual(
            MotionTokens.ambientInterval(full, energy: AmbientEnergy(thermal: .serious)),
            MotionTokens.conservingFrameInterval
        )
        XCTAssertTrue(MotionTokens.ambientPaused(AmbientEnergy(thermal: .critical)))
        XCTAssertFalse(MotionTokens.ambientPaused(AmbientEnergy(thermal: .serious)))
    }

    func testConservingNeverSpeedsUpSlowerLayers() {
        let reduced = MotionTokens.reducedFrameInterval // 8 fps is already slower than 10 fps
        XCTAssertEqual(MotionTokens.ambientInterval(reduced, energy: AmbientEnergy(lowPower: true)), reduced)
    }

    func testNoDecorativeTimelineHardCodesItsRate() throws {
        // Every TimelineView in UI/ must take its cadence from MotionTokens.ambientInterval.
        let ui = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("UI")
        let files = try FileManager.default.contentsOfDirectory(at: ui, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let timelines = text.components(separatedBy: "TimelineView(").count - 1
            let tokenized = text.components(separatedBy: "MotionTokens.ambientInterval(").count - 1
            if file.lastPathComponent == "MotionTokens.swift" { continue }
            XCTAssertLessThanOrEqual(timelines, tokenized, "\(file.lastPathComponent) has a TimelineView without ambientInterval")
        }
    }
}
