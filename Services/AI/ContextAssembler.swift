import Foundation
import Core

/// Assembles a compact, privacy-safe context block for the model.
/// Pure. No network, no storage side effects.
public struct ContextAssembler: Sendable {

    public struct Input: Sendable {
        public var personaID: String?
        public var personaDisplayName: String?
        public var recentMemorySnippets: [String]
        public var latestInsightTitles: [String]
        public var deviceSummary: String?

        public init(
            personaID: String? = nil,
            personaDisplayName: String? = nil,
            recentMemorySnippets: [String] = [],
            latestInsightTitles: [String] = [],
            deviceSummary: String? = nil
        ) {
            self.personaID = personaID
            self.personaDisplayName = personaDisplayName
            self.recentMemorySnippets = recentMemorySnippets
            self.latestInsightTitles = latestInsightTitles
            self.deviceSummary = deviceSummary
        }
    }

    public init() {}

    /// Produce a short context string. Empty if nothing useful is available.
    public func assemble(_ input: Input, maxMemoryLines: Int = 5, maxInsightLines: Int = 3) -> String? {
        var lines: [String] = []

        if let name = input.personaDisplayName, !name.isEmpty {
            lines.append("Active persona: \(name)")
        } else if let id = input.personaID {
            lines.append("Active persona: \(id)")
        }

        if let device = input.deviceSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !device.isEmpty {
            lines.append("Device: \(device)")
        }

        let memories = input.recentMemorySnippets
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxMemoryLines)
        if !memories.isEmpty {
            lines.append("Recent memory:")
            for memory in memories {
                lines.append("- \(memory.prefix(160))")
            }
        }

        let insights = input.latestInsightTitles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxInsightLines)
        if !insights.isEmpty {
            lines.append("Recent insights:")
            for insight in insights {
                lines.append("- \(insight.prefix(120))")
            }
        }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}
