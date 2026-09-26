import Foundation
import Core

/// Pure system-prompt composition for Mercury.
///
/// Order: core → aspect → (optional plain directive) → bias → memory → device → aspect label.
/// `{{owner}}` resolves to the owner name on-device, or `"the owner"` for cloud-bound prompts
/// so no identifier reaches a provider.
public enum PromptComposer {

    public enum Destination: Sendable, Equatable {
        case onDevice
        case cloud
    }

    public static let ownerPlaceholder = "{{owner}}"
    public static let cloudOwnerLabel = "the owner"
    public static let defaultOwnerName = "Christopher"

    private static let plainModeDirective =
        "Plain mode: he may be struggling or this is serious. No wit. Be warm, brief, and practical."

    public static func compose(
        core: String,
        aspect: String,
        bias: String = "",
        memory: [MemoryItem] = [],
        device: String = "",
        aspectLabel: String = "",
        plainMode: Bool = false,
        owner: String = defaultOwnerName,
        destination: Destination = .cloud
    ) -> String {
        let ownerToken = resolvedOwner(owner: owner, destination: destination)
        var parts: [String] = []

        let resolvedCore = substituteOwner(in: core, with: ownerToken)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedCore.isEmpty {
            parts.append(resolvedCore)
        }

        let resolvedAspect = substituteOwner(in: aspect, with: ownerToken)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !resolvedAspect.isEmpty {
            parts.append(resolvedAspect)
        }

        if plainMode {
            parts.append(plainModeDirective)
        }

        let trimmedBias = bias.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBias.isEmpty {
            parts.append("Behavioral posture (internal): \(trimmedBias)")
        }

        if !memory.isEmpty {
            parts.append(memoryBlock(memory))
        }

        let trimmedDevice = device.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedDevice.isEmpty {
            parts.append(trimmedDevice)
        }

        let trimmedLabel = aspectLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            parts.append("Active aspect: \(trimmedLabel).")
        }

        return parts.joined(separator: "\n\n")
    }

    public static func resolvedOwner(owner: String, destination: Destination) -> String {
        switch destination {
        case .onDevice:
            return owner
        case .cloud:
            return cloudOwnerLabel
        }
    }

    public static func substituteOwner(in text: String, with ownerToken: String) -> String {
        text.replacingOccurrences(of: ownerPlaceholder, with: ownerToken)
    }

    public static func formatMemoryDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func memoryBlock(_ memory: [MemoryItem]) -> String {
        var lines = ["Relevant memory (private, ranked by importance):"]
        for item in memory {
            let date = formatMemoryDate(item.createdAt)
            let snippet = String(item.value.prefix(180))
            lines.append("- (\(date)) [\(item.category.rawValue)] \(snippet)")
        }
        return lines.joined(separator: "\n")
    }
}
