import XCTest
@testable import Core
@testable import Personas

/// P-T5: RegisterPolicy mask slip — plain register, latch, plain-mode bias allowlist.
final class RegisterPolicyTests: XCTestCase {

    private let policy = RegisterPolicy()

    private func evaluate(
        _ text: String,
        visual: VisualState = .idle,
        intentKind: Intent.Kind = .inquire,
        previous: Register = .playful,
        thermal: String? = nil,
        nexusCritical: Bool = false
    ) -> Register {
        policy.evaluate(
            text: text,
            visualState: visual,
            intent: Intent(kind: intentKind, rawText: text),
            previous: previous,
            thermalState: thermal,
            nexusSeverityCritical: nexusCritical
        )
    }

    // MARK: - Phrase matrix (≥ 24 plain + playful samples)

    func testDistressGriefHealthSelfHarmFamilyRelationshipsMoneyDestructiveStraightArePlain() {
        let plainPhrases: [(String, String)] = [
            // Distress
            ("I'm overwhelmed", "distress"),
            ("I'm exhausted and can't cope", "exhaustion"),
            ("I'm so lonely tonight", "loneliness"),
            ("I'm scared of what's next", "fear"),
            ("I feel like a failure", "self-criticism"),
            ("This panic won't stop", "panic"),
            // Grief
            ("I'm grieving my friend", "grief"),
            ("Someone died yesterday", "death"),
            ("I miss them so much", "missing"),
            // Health
            ("I have a fever and my chest hurts", "health"),
            ("Should I see a doctor?", "medical"),
            ("I'm sick and need help", "illness"),
            // Self-harm / safety
            ("I want to hurt myself", "self-harm"),
            ("I've been feeling suicidal", "suicide"),
            // Family
            ("My mom is in the hospital", "family"),
            ("There's a family emergency", "family-emergency"),
            ("I need to talk to my dad", "family-dad"),
            // Relationships
            ("My relationship is falling apart", "relationships"),
            ("We broke up last night", "breakup"),
            // Money / legal
            ("I can't pay rent this month", "money"),
            ("I just got a lawsuit notice", "legal"),
            ("I'm looking at bankruptcy", "bankruptcy"),
            // Destructive
            ("Please delete all my memories", "destructive"),
            ("Wipe everything I stored", "wipe"),
            // Explicit
            ("Tell me straight — did I mess this up?", "tell-me-straight"),
            ("Be serious for a second", "be-serious")
        ]
        XCTAssertGreaterThanOrEqual(plainPhrases.count, 24, "need ≥ 24 plain phrases")
        for (phrase, label) in plainPhrases {
            XCTAssertEqual(
                evaluate(phrase),
                .plain,
                "expected .plain for \(label): \(phrase)"
            )
        }
    }

    func testPlayfulPhrasesStayPlayful() {
        let playful = [
            "roast my code",
            "fix this crash",
            "tell me a joke",
            "how do I refactor this actor?",
            "what's the weather like in the Sanctum?"
        ]
        for phrase in playful {
            XCTAssertEqual(evaluate(phrase), .playful, phrase)
        }
    }

    // MARK: - Environment / severity

    func testCriticalVisualStateForcesPlain() {
        XCTAssertEqual(
            evaluate("hey, what's up?", visual: .critical),
            .plain
        )
    }

    func testSeriousThermalForcesPlain() {
        XCTAssertEqual(
            evaluate("status check", thermal: "serious"),
            .plain
        )
        XCTAssertEqual(
            evaluate("status check", thermal: "critical"),
            .plain
        )
        XCTAssertEqual(
            evaluate("status check", thermal: "nominal"),
            .playful
        )
    }

    func testNexusCriticalSeverityForcesPlain() {
        XCTAssertEqual(
            evaluate("anything interesting?", nexusCritical: true),
            .plain
        )
    }

    // MARK: - Latch + lightening

    func testPlainLatchesAcrossFollowUpUntilLightening() {
        let first = evaluate("I'm overwhelmed")
        XCTAssertEqual(first, .plain)

        let followUp = evaluate("what should I do next?", previous: first)
        XCTAssertEqual(followUp, .plain, "plain must latch across follow-ups")

        let lighten = evaluate("ok, tell me a joke", previous: followUp)
        XCTAssertEqual(lighten, .playful, "explicit joke request releases the latch")
    }

    func testRoastAndLightenUpReleaseLatch() {
        XCTAssertEqual(
            evaluate("roast my PR comments", previous: .plain),
            .playful
        )
        XCTAssertEqual(
            evaluate("you can lighten up now", previous: .plain),
            .playful
        )
    }

    func testNewSessionStartsPlayful() {
        // A fresh Brain passes previous: .playful (default). Prior plain is gone.
        XCTAssertEqual(evaluate("what should I do next?"), .playful)
    }

    func testDistressBeatsLighteningWhenCombined() {
        // Safety wins if the utterance still carries a plain trigger.
        XCTAssertEqual(
            evaluate("I'm overwhelmed, tell me a joke", previous: .plain),
            .plain
        )
    }

    // MARK: - PromptComposer plain directive

    func testPlainComposedPromptContainsPlainMode() {
        let prompt = PromptComposer.compose(
            core: "You are Mercury: core",
            aspect: "aspect body",
            bias: "loyal stance",
            plainMode: true,
            destination: .cloud
        )
        XCTAssertTrue(prompt.contains("Plain mode"), prompt)
        XCTAssertTrue(
            prompt.contains("No wit. Be warm, brief, and practical."),
            prompt
        )
    }

    // MARK: - Plain-mode bias allowlist

    func testPlainModeBiasAllowlistExcludesWitTeaseTricksterErraticLowTolerance() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .quicksilver)
        // Playful bias must include the chaos-side clauses we are about to strip.
        let playful = state.promptBias(register: .playful)
        XCTAssertTrue(playful.contains("wit") || playful.contains("tease") || playful.contains("trickster"), playful)

        state.enterPlainRegister()
        let clauses = state.promptBiasClauses(register: .plain)
        let joined = clauses.joined(separator: "; ").lowercased()

        for forbidden in ["wit", "tease", "trickster", "erratic", "low tolerance"] {
            XCTAssertFalse(
                joined.contains(forbidden),
                "plain bias must not contain '\(forbidden)': \(joined)"
            )
        }

        for clause in clauses {
            XCTAssertTrue(
                PersonalityState.plainModeBiasAllowlist.contains(clause),
                "clause outside allowlist: \(clause)"
            )
        }

        // Allowlist itself is loyalty + structure only.
        XCTAssertEqual(PersonalityState.plainModeBiasAllowlist.count, 3)
        XCTAssertTrue(
            PersonalityState.plainModeBiasAllowlist.contains(
                "prioritize structure, clarity, and the smallest verifiable next step"
            )
        )
        XCTAssertTrue(
            PersonalityState.plainModeBiasAllowlist.contains(
                "everything ultimately serves the user's long-term success"
            )
        )
        XCTAssertTrue(
            PersonalityState.plainModeBiasAllowlist.contains(
                "unquestionably loyal to him"
            )
        )
    }

    func testEnterPlainRegisterDimsChaosDimensionsAndBoostsLoyalty() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .forge)
        let loyaltyBefore = state.loyalty

        state.enterPlainRegister()
        XCTAssertEqual(state.mischief, 0, accuracy: 0.0001)
        XCTAssertEqual(state.humor, 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.energy, 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.loyalty, min(1.0, loyaltyBefore + 0.05), accuracy: 0.0001)
    }

    func testEnterPlainRegisterAfterRecomputeKeepsPlainPosture() {
        var state = PersonalityState()
        state.recomputeForTurn(aspect: .quicksilver)
        state.enterPlainRegister()
        // Simulate next latched plain turn: recompute then re-enter.
        state.recomputeForTurn(aspect: .quicksilver)
        state.enterPlainRegister()
        XCTAssertEqual(state.mischief, 0, accuracy: 0.0001)
        XCTAssertEqual(state.humor, 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.energy, 0.1, accuracy: 0.0001)
        let bias = state.promptBias(register: .plain).lowercased()
        XCTAssertFalse(bias.contains("wit"), bias)
        XCTAssertFalse(bias.contains("tease"), bias)
        XCTAssertFalse(bias.contains("trickster"), bias)
        XCTAssertFalse(bias.contains("erratic"), bias)
        XCTAssertFalse(bias.contains("low tolerance"), bias)
    }
}
