import XCTest
@testable import Personas
@testable import Core

/// P-T18: PersonalityState + PersonaConfiguration retune for controlled chaos.
final class PersonalityTuningTests: XCTestCase {

    // Bible §3.2 baselines (before adjustForAspect).
    private let bible: [Aspect: [PersonalityState.Dimension: Double]] = [
        .quicksilver: [
            .confidence: 0.84, .curiosity: 0.80, .humor: 0.82, .mischief: 0.72,
            .focus: 0.60, .initiative: 0.70, .skepticism: 0.82, .patience: 0.30,
            .loyalty: 0.95, .energy: 0.70
        ],
        .forge: [
            .confidence: 0.88, .curiosity: 0.90, .humor: 0.60, .mischief: 0.62,
            .focus: 0.82, .initiative: 0.90, .skepticism: 0.78, .patience: 0.30,
            .loyalty: 0.95, .energy: 0.95
        ],
        .eternal: [
            .confidence: 0.90, .curiosity: 0.35, .humor: 0.18, .mischief: 0.12,
            .focus: 0.85, .initiative: 0.22, .skepticism: 0.70, .patience: 0.98,
            .loyalty: 0.98, .energy: 0.10
        ]
    ]

    private func value(_ state: PersonalityState, _ dim: PersonalityState.Dimension) -> Double {
        switch dim {
        case .confidence: return state.confidence
        case .curiosity: return state.curiosity
        case .humor: return state.humor
        case .mischief: return state.mischief
        case .focus: return state.focus
        case .initiative: return state.initiative
        case .skepticism: return state.skepticism
        case .patience: return state.patience
        case .loyalty: return state.loyalty
        case .energy: return state.energy
        }
    }

    private func snapshot(_ state: PersonalityState) -> [PersonalityState.Dimension: Double] {
        Dictionary(uniqueKeysWithValues: PersonalityState.Dimension.allCases.map { ($0, value(state, $0)) })
    }

    // MARK: - Bible table

    func testAspectBaselinesMatchBible() {
        for aspect in Aspect.allCases {
            var state = PersonalityState()
            state.applyPersonaBias(personaID: aspect.rawValue)
            guard let expected = bible[aspect] else {
                XCTFail("missing bible row for \(aspect)")
                continue
            }
            for dim in PersonalityState.Dimension.allCases {
                let got = value(state, dim)
                let want = expected[dim]!
                XCTAssertEqual(
                    got, want, accuracy: 0.0001,
                    "\(aspect).\(dim.rawValue): got \(got) want \(want)"
                )
            }
        }
    }

    func testForgeFocusSurvivesAdjustForStructureClause() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .forge)
        XCTAssertGreaterThan(state.focus, 0.75, "Forge focus must keep the structure bias clause")
        let bias = state.promptBias()
        XCTAssertTrue(
            bias.contains("prioritize structure, clarity, and the smallest verifiable next step"),
            bias
        )
    }

    // MARK: - promptBias loyalty / teasing

    func testPromptBiasAffectionateTeasingNeverThePerson() {
        for aspect in Aspect.allCases {
            var state = PersonalityState()
            state.recomputeForTurn(aspect: aspect)
            let bias = state.promptBias()
            XCTAssertFalse(bias.contains("never the person"), "\(aspect): \(bias)")
            XCTAssertTrue(bias.contains("always on his side"), "\(aspect): \(bias)")
            XCTAssertTrue(bias.contains("tease with affection"), "\(aspect): \(bias)")
        }
    }

    func testEnergyAndLoyaltyBiasClauses() {
        var forge = PersonalityState()
        forge.recomputeForTurn(aspect: .forge)
        XCTAssertTrue(forge.promptBias().contains("erratic bursts, then a crisp landing"))
        XCTAssertTrue(forge.promptBias().contains("unquestionably loyal to him"))

        var eternal = PersonalityState()
        eternal.recomputeForTurn(aspect: .eternal)
        XCTAssertTrue(eternal.promptBias().contains("few words; let silence work"))
        XCTAssertTrue(eternal.promptBias().contains("unquestionably loyal to him"))
    }

    // MARK: - PersonaConfiguration dials

    func testTemperaturesInControlledChaosRange() {
        let open = PersonaConfiguration.quicksilver.preferredTemperature
        let forge = PersonaConfiguration.forge.preferredTemperature
        let eternal = PersonaConfiguration.eternal.preferredTemperature
        for (name, temp) in [("open", open), ("forge", forge), ("eternal", eternal)] {
            XCTAssertGreaterThanOrEqual(temp, 0.3, name)
            XCTAssertLessThanOrEqual(temp, 0.75, name)
        }
        XCTAssertEqual(open, 0.7, accuracy: 0.0001)
        XCTAssertEqual(forge, 0.45, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(forge, 0.5)
        XCTAssertEqual(eternal, 0.35, accuracy: 0.0001)
    }

    func testMaxTokensHintOrderedForgeOpenEternal() {
        let open = PersonaConfiguration.quicksilver.maxTokensHint
        let forge = PersonaConfiguration.forge.maxTokensHint
        let eternal = PersonaConfiguration.eternal.maxTokensHint
        XCTAssertEqual(open, 1024)
        XCTAssertEqual(forge, 1536)
        XCTAssertEqual(eternal, 512)
        XCTAssertGreaterThan(forge, open)
        XCTAssertGreaterThan(open, eternal)
    }

    // MARK: - Idempotence + nudge deltas

    func testRecomputeIsIdempotentAcrossTenTurns() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .quicksilver)
        let first = snapshot(state)
        for _ in 0..<9 {
            state.recomputeForTurn(aspect: .quicksilver)
        }
        XCTAssertEqual(snapshot(state), first)
    }

    func testNudgeSurvivesWhileRecomputeStaysIdempotent() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .forge)
        let baselineFocus = state.focus
        let baselineConfidence = state.confidence

        state.noteInteraction()
        let afterNudgeConfidence = state.confidence
        let afterNudgePatience = state.patience
        XCTAssertGreaterThan(afterNudgeConfidence, baselineConfidence)
        XCTAssertLessThan(afterNudgePatience, 0.30) // forge patience base 0.30, then −0.01

        // Recompute must not erase the nudge.
        state.recomputeForTurn(aspect: .forge)
        XCTAssertEqual(state.confidence, afterNudgeConfidence, accuracy: 0.0001)
        XCTAssertEqual(state.patience, afterNudgePatience, accuracy: 0.0001)
        XCTAssertEqual(state.focus, baselineFocus, accuracy: 0.0001)

        let bias = state.promptBias()
        XCTAssertTrue(bias.contains("always on his side"), bias)

        // Further recomputes stay stable with the same nudge.
        let mid = snapshot(state)
        for _ in 0..<5 {
            state.recomputeForTurn(aspect: .forge)
        }
        XCTAssertEqual(snapshot(state), mid)
    }

    func testLivingStatusStyleNudgePersists() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .quicksilver)
        let before = state.skepticism
        state.increase(.skepticism, by: 0.04) // refreshLivingStatus style
        let nudged = state.skepticism
        XCTAssertEqual(nudged, before + 0.04, accuracy: 0.0001)
        state.recomputeForTurn(aspect: .quicksilver)
        XCTAssertEqual(state.skepticism, nudged, accuracy: 0.0001)
    }

    // MARK: - AspectPolicy environment (SPM stand-in for AppTests)

    func testOpenTurnMovesToForgeUnderLowPower() {
        let policy = AspectPolicy()
        let intent = Intent(kind: .inquire)
        let env = AspectPolicy.Environment(isLowPower: true, thermalState: "nominal")
        XCTAssertEqual(policy.aspectForTurn(intent: intent), .quicksilver)
        XCTAssertEqual(policy.aspectForTurn(intent: intent, environment: env), .forge)
    }

    func testOpenTurnMovesToForgeUnderSeriousThermal() {
        let policy = AspectPolicy()
        let intent = Intent(kind: .express)
        let env = AspectPolicy.Environment(isLowPower: false, thermalState: "serious")
        XCTAssertEqual(policy.aspectForTurn(intent: intent, environment: env), .forge)
        let critical = AspectPolicy.Environment(thermalState: "critical")
        XCTAssertEqual(policy.aspectForTurn(intent: intent, environment: critical), .forge)
    }

    func testEnvironmentDoesNotOverrideForgeOrEternalIntent() {
        let policy = AspectPolicy()
        let env = AspectPolicy.Environment(isLowPower: true, thermalState: "serious")
        XCTAssertEqual(
            policy.aspectForTurn(intent: Intent(kind: .create), environment: env),
            .forge
        )
        XCTAssertEqual(
            policy.aspectForTurn(intent: Intent(kind: .remember), environment: env),
            .eternal
        )
    }

    func testAdjustForAspectNoLongerDampsForgeMischiefOrHumor() {
        var state = PersonalityState()
        state.applyPersonaBias(personaID: "forge")
        let mischiefBefore = state.mischief
        let humorBefore = state.humor
        state.adjustForAspect(.forge)
        XCTAssertEqual(state.mischief, mischiefBefore, accuracy: 0.0001)
        XCTAssertEqual(state.humor, humorBefore, accuracy: 0.0001)
        XCTAssertEqual(state.energy, min(1.0, 0.95 + 0.03), accuracy: 0.0001)
        XCTAssertEqual(state.focus, min(1.0, 0.82 + 0.05), accuracy: 0.0001)
    }
}
