import Foundation
import Core

/// M3-T11 choke point. Cloud payloads are assembled here and nowhere else.
/// A tier that trains on prompts cannot receive standard context.
public enum CloudContextLevel: String, Sendable, Equatable {
    case standard
    case minimal
}

public struct CloudContextBlock: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case question
        case turn
        case memory
        case device
    }

    public let kind: Kind
    public let text: String

    public init(kind: Kind, text: String) {
        self.kind = kind
        self.text = text
    }
}

public enum CloudContextPolicy {
    public static let memoryCharCap = 180
    public static let standardTurnCap = 4
    public static let minimalTurnCap = 2
    public static let standardMemoryCap = 3

    public static func resolvedLevel(
        requested: CloudContextLevel,
        trainsOnPrompts: Bool
    ) -> CloudContextLevel {
        trainsOnPrompts ? .minimal : requested
    }

    /// Kind-tagged blocks. Private memories, key-like records, and raw diagnostics never leave.
    public static func assemble(
        question: String,
        recentTurns: [String],
        memories: [MemoryItem],
        coarseDeviceLine: String?,
        requested: CloudContextLevel,
        trainsOnPrompts: Bool
    ) -> [CloudContextBlock] {
        let level = resolvedLevel(requested: requested, trainsOnPrompts: trainsOnPrompts)
        let turnCap = level == .minimal ? minimalTurnCap : standardTurnCap
        var blocks = [CloudContextBlock(kind: .question, text: question)]
        for turn in recentTurns.suffix(turnCap) {
            let trimmed = turn.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            blocks.append(CloudContextBlock(kind: .turn, text: trimmed))
        }
        guard level == .standard else { return blocks }

        let notes = memories
            .filter { isShareable($0) }
            .prefix(standardMemoryCap)
        for note in notes {
            blocks.append(
                CloudContextBlock(kind: .memory, text: String(note.value.prefix(memoryCharCap)))
            )
        }
        if let line = sanitizedDeviceLine(coarseDeviceLine) {
            blocks.append(CloudContextBlock(kind: .device, text: line))
        }
        return blocks
    }

    static func isShareable(_ item: MemoryItem) -> Bool {
        let flag = item.metadata["private"]?.lowercased()
        if flag == "true" || flag == "1" || flag == "yes" { return false }
        let key = item.key.lowercased()
        if key.contains("key") || key.contains("token") || key.contains("secret") { return false }
        return true
    }

    static func sanitizedDeviceLine(_ line: String?) -> String? {
        guard let raw = line?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lowered = raw.lowercased()
        if lowered.contains("diagnostic") || lowered.contains("nexus") { return nil }
        if raw.contains("@") || raw.contains("://") { return nil }
        if raw.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) {
            return nil
        }
        return raw
    }
}
