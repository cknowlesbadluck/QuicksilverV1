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
        let createdAt = Date()
        let first = Intent(id: id, kind: .remember, rawText: "note this", confidence: 0.9, createdAt: createdAt)
        let second = Intent(id: id, kind: .remember, rawText: "note this", confidence: 0.9, createdAt: createdAt)
        XCTAssertEqual(first, second)
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
        XCTAssertGreaterThan(
            ResourcePlan.elevated.maxContextTokens,
            ResourcePlan.interactive.maxContextTokens
        )
    }

    func testResourcePlanClamps() {
        let plan = ResourcePlan(
            maxContextTokens: -10,
            maxOutputTokens: -5,
            maxWallClockSeconds: 0.1
        )
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

    // MARK: - IntentEngine

    func testIntentEngineDiagnose() {
        let engine = IntentEngine()
        let intent = engine.classify("why is the battery draining so fast")
        XCTAssertEqual(intent.kind, .diagnose)
        XCTAssertGreaterThan(intent.confidence, 0.8)
    }

    func testIntentEngineRemember() {
        let engine = IntentEngine()
        let intent = engine.classify("remember this for later")
        XCTAssertEqual(intent.kind, .remember)
    }

    func testIntentEngineCreate() {
        let engine = IntentEngine()
        let intent = engine.classify("implement the new architecture module")
        XCTAssertEqual(intent.kind, .create)
    }

    func testIntentEngineInquireDefault() {
        let engine = IntentEngine()
        let intent = engine.classify("what do you think about this approach")
        XCTAssertEqual(intent.kind, .inquire)
    }

    func testIntentEngineEmpty() {
        let engine = IntentEngine()
        let intent = engine.classify("   ")
        XCTAssertEqual(intent.kind, .unknown)
        XCTAssertEqual(intent.confidence, 0)
    }

    // MARK: - AspectPolicy

    func testAspectPolicyTurnMapping() {
        let policy = AspectPolicy()
        XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: .create)), .forge)
        XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: .diagnose)), .forge)
        XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: .observe)), .eternal)
        XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: .remember)), .eternal)
        XCTAssertEqual(policy.aspectForTurn(intent: Intent(kind: .inquire)), .quicksilver)
    }

    func testAspectPolicyDwellPreventsChange() {
        let policy = AspectPolicy(minimumDwellSeconds: 60 * 60)
        let recent = Date()
        let result = policy.preferredAspect(
            current: .quicksilver,
            lastChangedAt: recent,
            intent: Intent(kind: .create)
        )
        XCTAssertNil(result)
    }

    func testAspectPolicyLowPowerTiltsForge() {
        let policy = AspectPolicy(minimumDwellSeconds: 0)
        let result = policy.preferredAspect(
            current: .quicksilver,
            lastChangedAt: nil,
            intent: nil,
            isLowPower: true
        )
        XCTAssertEqual(result, .forge)
    }


    func testAspectPolicyOpenTurnEnvironmentForcesForge() {
        let policy = AspectPolicy()
        let inquire = Intent(kind: .inquire)
        XCTAssertEqual(
            policy.aspectForTurn(
                intent: inquire,
                environment: AspectPolicy.Environment(isLowPower: true)
            ),
            .forge
        )
        XCTAssertEqual(
            policy.aspectForTurn(
                intent: inquire,
                environment: AspectPolicy.Environment(thermalState: "serious")
            ),
            .forge
        )
        // Eternal / Forge intents are not overridden by environment.
        XCTAssertEqual(
            policy.aspectForTurn(
                intent: Intent(kind: .observe),
                environment: AspectPolicy.Environment(isLowPower: true, thermalState: "critical")
            ),
            .eternal
        )
    }

    // MARK: - IntelligenceBroker

    func testBrokerAllowsInteractive() {
        let broker = IntelligenceBroker()
        let decision = broker.evaluate(
            IntelligenceBroker.TurnRequest(
                intent: Intent(kind: .inquire),
                aspect: .quicksilver,
                plan: .interactive,
                estimatedContextTokens: 1_000
            )
        )
        if case .allow = decision {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected allow")
        }
    }

    func testBrokerElevatesForge() {
        let broker = IntelligenceBroker()
        let decision = broker.evaluate(
            IntelligenceBroker.TurnRequest(
                intent: Intent(kind: .create),
                aspect: .forge,
                plan: .interactive,
                estimatedContextTokens: 500
            )
        )
        if case .allow(let plan) = decision {
            XCTAssertEqual(plan.priority, .high)
        } else {
            XCTFail("expected allow elevated")
        }
    }

    func testBrokerDegradesOversizedContext() {
        let broker = IntelligenceBroker()
        let decision = broker.evaluate(
            IntelligenceBroker.TurnRequest(
                intent: Intent(kind: .inquire),
                aspect: .quicksilver,
                plan: .interactive,
                estimatedContextTokens: 50_000
            )
        )
        if case .degrade(let plan, _) = decision {
            XCTAssertLessThanOrEqual(plan.maxOutputTokens, 512)
        } else {
            XCTFail("expected degrade")
        }
    }

    func testBrokerDefaultPlans() {
        let broker = IntelligenceBroker()
        XCTAssertEqual(broker.defaultPlan(for: Intent(kind: .create)).priority, .high)
        XCTAssertFalse(broker.defaultPlan(for: Intent(kind: .observe)).allowExternalCalls)
    }
}
