import Foundation
import Core

/// M3-T11 choke point. Cloud payloads are assembled here and nowhere else.
/// A tier that trains on prompts cannot receive standard context.
public enum CloudContextLevel: String, Sendable, Equatable {
    case standard
    case minimal

    public init(aiLevel: AIContextLevel) {
        switch aiLevel {
        case .standard: self = .standard
        case .minimal: self = .minimal
        }
    }
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

/// Inputs for `CloudContextPolicy.assemble` (keeps the call site ≤5 parameters).
public struct CloudContextInput: Sendable, Equatable {
    public let question: String
    public let recentTurns: [String]
    public let memories: [MemoryItem]
    public let coarseDeviceLine: String?

    public init(
        question: String,
        recentTurns: [String] = [],
        memories: [MemoryItem] = [],
        coarseDeviceLine: String? = nil
    ) {
        self.question = question
        self.recentTurns = recentTurns
        self.memories = memories
        self.coarseDeviceLine = coarseDeviceLine
    }
}

public enum CloudContextPolicy {
    public static let memoryCharCap = 180
    public static let standardTurnCap = 4
    public static let minimalTurnCap = 2
    public static let standardMemoryCap = 3

    /// Allowlisted coarse device vocabulary only — never free-form identifiers.
    public static let allowedDeviceLines: Set<String> = [
        "battery low",
        "battery critical",
        "battery ok",
        "battery full",
        "thermal nominal",
        "thermal fair",
        "thermal serious",
        "thermal critical",
        "low power"
    ]

    /// Complete key-path segments treated as credential markers (not substrings).
    public static let credentialKeySegments: Set<String> = [
        "key", "token", "secret", "password", "apikey", "auth", "bearer"
    ]

    public static func resolvedLevel(
        requested: CloudContextLevel,
        trainsOnPrompts: Bool
    ) -> CloudContextLevel {
        trainsOnPrompts ? .minimal : requested
    }

    public static func turnCap(for level: CloudContextLevel) -> Int {
        level == .minimal ? minimalTurnCap : standardTurnCap
    }

    /// Cap prior user/assistant pairs for the outbound cloud request.
    public static func cappedHistory(
        _ history: [Message],
        level: CloudContextLevel
    ) -> [Message] {
        let maxMessages = turnCap(for: level) * 2
        guard history.count > maxMessages else { return history }
        return Array(history.suffix(maxMessages))
    }

    /// Kind-tagged blocks. Private memories, credentials, and raw diagnostics never leave.
    /// Conversation turns travel only via `cappedHistory` → `AIRequest.history` (not duplicated here).
    public static func assemble(
        _ input: CloudContextInput,
        level: CloudContextLevel
    ) -> [CloudContextBlock] {
        var blocks = [CloudContextBlock(kind: .question, text: input.question)]
        guard level == .standard else { return blocks }

        let notes = shareableMemories(input.memories, cap: standardMemoryCap)
        for note in notes {
            blocks.append(
                CloudContextBlock(kind: .memory, text: String(note.value.prefix(memoryCharCap)))
            )
        }
        if let line = sanitizedDeviceLine(input.coarseDeviceLine) {
            blocks.append(CloudContextBlock(kind: .device, text: line))
        }
        return blocks
    }

    /// Shareable memories with backfill after private/credential filtering.
    public static func shareableMemories(_ memories: [MemoryItem], cap: Int) -> [MemoryItem] {
        Array(memories.filter { isShareable($0) }.prefix(max(0, cap)))
    }

    /// Appendix for direct providers that ignore `AIRequest.context` (e.g. Grok).
    public static func systemAppendix(from context: [GatewayContextBlock]) -> String {
        var parts: [String] = []
        let memories = context.filter { $0.kind == .memory }.map(\.text)
        if !memories.isEmpty {
            parts.append("Relevant memory (cloud-safe):")
            parts.append(contentsOf: memories.map { "- \($0)" })
        }
        if let device = context.first(where: { $0.kind == .device })?.text {
            parts.append("Device: \(device).")
        }
        return parts.joined(separator: "\n")
    }

    /// Map policy blocks to gateway wire context (question + turns stay in messages).
    public static func gatewayContext(
        from blocks: [CloudContextBlock]
    ) -> [GatewayContextBlock] {
        blocks.compactMap { block in
            switch block.kind {
            case .question, .turn:
                return nil
            case .memory:
                return GatewayContextBlock(kind: .memory, text: block.text, privacy: .device)
            case .device:
                return GatewayContextBlock(kind: .device, text: block.text, privacy: .device)
            }
        }
    }

    /// Derive an allowlisted coarse device line from Nexus-ish signals.
    /// Severity order: thermal critical/serious → low power → battery → milder thermal.
    public static func coarseDeviceLine(
        batteryLevel: Double?,
        thermalState: String,
        lowPowerMode: Bool
    ) -> String? {
        let thermal = thermalState.lowercased()
        if thermal == "critical" { return "thermal critical" }
        if thermal == "serious" { return "thermal serious" }
        if lowPowerMode { return "low power" }
        if let battery = batteryCoarseLine(batteryLevel) { return battery }
        return thermalCoarseLine(thermalState)
    }

    private static func batteryCoarseLine(_ level: Double?) -> String? {
        guard let level else { return nil }
        if level < 0.15 { return "battery critical" }
        if level < 0.25 { return "battery low" }
        if level >= 0.95 { return "battery full" }
        if level >= 0.5 { return "battery ok" }
        return nil
    }

    private static func thermalCoarseLine(_ thermalState: String) -> String? {
        switch thermalState.lowercased() {
        case "critical": return "thermal critical"
        case "serious": return "thermal serious"
        case "fair": return "thermal fair"
        case "nominal": return "thermal nominal"
        default: return nil
        }
    }

    public static func isShareable(_ item: MemoryItem) -> Bool {
        if isPrivateFlag(item.metadata["private"]) { return false }
        if keyHasCredentialSegment(item.key) { return false }
        if valueLooksLikeCredential(item.value) { return false }
        return true
    }

    static func isPrivateFlag(_ raw: String?) -> Bool {
        guard let raw else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "1", "yes": return true
        default: return false
        }
    }

    static func keyHasCredentialSegment(_ key: String) -> Bool {
        let parts = key.lowercased().split { character in
            character == "." || character == "_" || character == "-"
        }.map(String.init)
        return parts.contains { credentialKeySegments.contains($0) }
    }

    /// Narrow credential-value check — not a general classifier.
    static func valueLooksLikeCredential(_ value: String) -> Bool {
        let lowered = value.lowercased()
        let phrases = [
            "api key", "api_key", "apikey", "api token",
            "access token", "secret key", "secret token",
            "token:", "bearer ", "password:"
        ]
        if phrases.contains(where: { lowered.contains($0) }) { return true }
        // Common key prefixes (sk-/pk-/api_) followed by a long token-like run.
        let pattern = #"(sk|pk|api)[-_][a-z0-9]{16,}"#
        return lowered.range(of: pattern, options: .regularExpression) != nil
    }

    static func sanitizedDeviceLine(_ line: String?) -> String? {
        guard let raw = line?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        let lowered = raw.lowercased()
        return allowedDeviceLines.contains(lowered) ? lowered : nil
    }
}
