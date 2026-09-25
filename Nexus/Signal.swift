import Foundation

/// Unified signal representation for the Nexus awareness layer.
public struct Signal: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let source: Source
    public let category: Category
    public let timestamp: Date
    public let value: String
    public let numericValue: Double?
    public let confidence: Double
    public let metadata: [String: String]

    public enum Source: String, Sendable, Codable, CaseIterable {
        case network, battery, storage, device, lifecycle, user, system
    }

    public enum Category: String, Sendable, Codable, CaseIterable {
        case connectivity, power, capacity, performance, environment, diagnostic
    }

    public init(
        id: UUID = UUID(),
        source: Source,
        category: Category,
        timestamp: Date = Date(),
        value: String,
        numericValue: Double? = nil,
        confidence: Double = 1.0,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.category = category
        self.timestamp = timestamp
        self.value = value
        self.numericValue = numericValue
        self.confidence = min(max(confidence, 0), 1)
        self.metadata = metadata
    }
}
