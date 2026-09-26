import Foundation

/// Named token/word budgets for Mercury system prompts (P-T3).
///
/// Est. tokens use the repo heuristic `chars / 4`, matching
/// `BrainComposition.estimateContextTokens`. Measured with `{{owner}}`
/// replaced by ``longestOwnerSubstitution`` (the longest of the on-device
/// owner name and the cloud-neutral label).
public enum PromptBudget {

    // MARK: - Caps (roadmap P-T3)

    /// Each aspect file: word ceiling.
    public static let aspectMaxWords = 350
    /// Each aspect file: est. token ceiling.
    public static let aspectMaxTokens = 260
    /// `core.txt` est. token ceiling.
    public static let coreMaxTokens = 420
    /// `core-compact.txt` est. token ceiling.
    public static let compactMaxTokens = 160
    /// Full path: core + aspect + max `promptBias()` (before memory/device).
    public static let fullComposedMaxTokens = 820
    /// Compact path: compact + aspect (before bias).
    public static let compactComposedMaxTokens = 420
    /// Compact path: compact + aspect + at most two bias clauses.
    public static let compactComposedWithBiasMaxTokens = 470
    /// Compact-mode bias keeps at most this many `promptBias()` clauses.
    public static let compactBiasClauseLimit = 2

    // MARK: - Owner substitution for measurement

    /// Longest value `PromptComposer` may substitute for `{{owner}}`.
    public static let longestOwnerSubstitution: String = {
        let candidates = [
            PromptComposer.defaultOwnerName,
            PromptComposer.cloudOwnerLabel
        ]
        return candidates.max(by: { $0.count < $1.count }) ?? PromptComposer.defaultOwnerName
    }()

    // MARK: - Pure estimators

    /// Whitespace-separated word count (Unicode-aware via `Character` splits on whitespace).
    public static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Est. tokens ≈ `chars / 4` (integer division), matching BrainComposition.
    public static func estimatedTokens(_ text: String) -> Int {
        text.count / 4
    }

    /// Substitute `{{owner}}` with ``longestOwnerSubstitution`` and trim.
    public static func preparedForMeasurement(_ text: String) -> String {
        PromptComposer.substituteOwner(in: text, with: longestOwnerSubstitution)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Split a `promptBias()` string into its `; `-joined clauses.
    public static func biasClauses(from bias: String) -> [String] {
        bias.split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Worst-case `promptBias()`: every clause that `PersonalityState.promptBias()` can emit.
    public static func maximumPromptBias() -> String {
        var state = PersonalityState()
        state.skepticism = 1
        state.focus = 1
        state.humor = 1
        state.mischief = 1
        state.patience = 0
        state.curiosity = 1
        state.confidence = 1
        state.loyalty = 1
        return state.promptBias()
    }

    /// Up to ``compactBiasClauseLimit`` longest clauses (worst-case compact-mode bias).
    public static func compactModeBias(from bias: String = maximumPromptBias()) -> String {
        let clauses = biasClauses(from: bias)
            .sorted { $0.count > $1.count }
            .prefix(compactBiasClauseLimit)
        return clauses.joined(separator: "; ")
    }

    /// Compose core + aspect (+ optional bias) the same way `PromptComposer` does
    /// for the system-prompt head (no memory, device, label, or plain directive).
    public static func composedHead(core: String, aspect: String, bias: String = "") -> String {
        PromptComposer.compose(
            core: core,
            aspect: aspect,
            bias: bias,
            memory: [],
            device: "",
            aspectLabel: "",
            plainMode: false,
            owner: longestOwnerSubstitution,
            destination: .onDevice
        )
    }
}
