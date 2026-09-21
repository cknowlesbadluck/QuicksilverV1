import XCTest
@testable import Core

final class CoreContractsTests: XCTestCase {

    // MARK: - Intent

    func testIntentDefaults() {
        let intent = Intent(kind: .inquire)
        XCTAssertEqual(intent.kind, .inquire)
        XCTAssertNil(intent.rawText)
        XCTAssertEqual(intent.confidence, 1.0)
        XCTAssertNotNil(intent.id)
    }

    func testIntentConfidenceClamped() {
        let low = Intent(kind: .unknown, confidence: -0.5)
        let high = Intent(kind: .unknown, confidence: 1.5)
        XCTAssertEqual(low.confidence, 0)
        XCTAssertEqual(high.confidence, 1)
    }

    func testIntentEquality() {
        let id = UUID()
        let a = Intent(id: id, kind: .remember, rawText: "note this", confidence: 0.9)
        let b = Intent(id: id, kind: .remember, rawText: "note this", confidence: 0.9)
        XCTAssertEqual(a, b)
    }

    // MARK: - Aspect

    func testAspectCases() {
        XCTAssertEqual(Aspect.allCases.count, 3)
        XCTAssertEqual(Aspect.quicksilver.diagnosticLabel, "Quicksilver")
        XCTAssertEqual(Aspect.forge.diagnosticLabel, "Forge")
        XCTAssertEqual(Aspect.eternal.diagnosticLabel, "Eternal")
    }

    func testAspectDefaultVisualState() {
        XCTAssertEqual(Aspect.quicksilver.defaultVisualState, .idle)
        XCTAssertEqual(Aspect.forge.defaultVisualState, .thinking)
        XCTAssertEqual(Aspect.eternal.defaultVisualState, .listening)
    }

    // MARK: - Capability

    func testCanonicalCapabilities() {
        XCTAssertEqual(Capability.remember.kind, .memoryWrite)
        XCTAssertEqual(Capability.retrieve.kind, .memoryRead)
        XCTAssertEqual(Capability.correct.kind, .memoryCorrect)
        XCTAssertEqual(Capability.express.kind, .express)
        XCTAssertFalse(Capability.diagnose.requiresUserInitiation)
        XCTAssertTrue(Capability.remember.requiresUserInitiation)
    }

    func testCapabilityIdentity() {
        XCTAssertEqual(Capability.remember.id, "capability.remember")
        XCTAssertNotEqual(Capability.remember, Capability.retrieve)
    }

    // MARK: - ResourcePlan

    func testResourcePlanDefaults() {
        let plan = ResourcePlan()
        XCTAssertEqual(plan.maxContextTokens, 8_192)
        XCTAssertEqual(plan.maxOutputTokens, 1_024)
        XCTAssertEqual(plan.maxWallClockSeconds, 45)
        XCTAssertTrue(plan.allowExternalCalls)
        XCTAssertEqual(plan.priority, .normal)
    }

    func testResourcePlanPresets() {
        XCTAssertEqual(ResourcePlan.background.priority, .low)
        XCTAssertFalse(ResourcePlan.background.allowExternalCalls)
        XCTAssertEqual(ResourcePlan.elevated.priority, .high)
        XCTAssertGreaterThan(ResourcePlan.elevated.maxContextTokens, ResourcePlan.interactive.maxContextTokens)
    }

    func testResourcePlanClamps() {
        let plan = ResourcePlan(maxContextTokens: -10, maxOutputTokens: -5, maxWallClockSeconds: 0.1)
        XCTAssertEqual(plan.maxContextTokens, 0)
        XCTAssertEqual(plan.maxOutputTokens, 0)
        XCTAssertEqual(plan.maxWallClockSeconds, 1)
    }

    // MARK: - VisualState

    func testVisualStateEnergyBounds() {
        for state in VisualState.allCases {
            XCTAssertGreaterThanOrEqual(state.ambientEnergy, 0)
            XCTAssertLessThanOrEqual(state.ambientEnergy, 1)
            XCTAssertGreaterThan(state.coreBrightness, 0)
            XCTAssertGreaterThan(state.particleMultiplier, 0)
        }
    }

    func testVisualStateElevated() {
        XCTAssertTrue(VisualState.thinking.isElevated)
        XCTAssertTrue(VisualState.processing.isElevated)
        XCTAssertTrue(VisualState.critical.isElevated)
        XCTAssertFalse(VisualState.idle.isElevated)
        XCTAssertFalse(VisualState.sleeping.isElevated)
        XCTAssertEqual(VisualState.elevated, .processing)
    }
}
