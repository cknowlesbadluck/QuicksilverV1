import Foundation

/// A classified desire or directive that the intelligence surface can act on.
/// Produced by the Intent engine (future); consumed by Aspect policy and Broker.
/// Pure value type — no side effects, no UI knowledge.
public struct Intent: Sendable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let kind: Kind
    public let rawText: String?
    public let confidence: Double
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        rawText: String? = nil,
        confidence: Double = 1.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.rawText = rawText
        self.confidence = min(max(confidence, 0), 1)
        self.createdAt = createdAt
    }

    public enum Kind: String, Sendable, Equatable, CaseIterable {
        case inquire
        case remember
        case retrieve
        case create
        case observe
        case diagnose
        case express
        case switchAspect
        case unknown
    }
}
