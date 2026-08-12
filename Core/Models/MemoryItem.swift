import Foundation

/// First-class memory entry. Lives in Core so both Memory and higher layers can share the type.
public struct MemoryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let key: String
    public let category: Category
    public var value: String
    public let createdAt: Date
    public var updatedAt: Date
    public var metadata: [String: String]

    /// Importance in the range 0.0 ... 1.0.
    public var importance: Double

    /// Optional persona that primarily owns this memory. nil = shared.
    public var personaScope: String?

    public enum Category: String, Codable, Sendable, CaseIterable {
        case preference, conversation, project, system, temporary
    }

    public init(
        id: UUID = UUID(),
        key: String,
        category: Category,
        value: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        metadata: [String: String] = [:],
        importance: Double = 0.5,
        personaScope: String? = nil
    ) {
        self.id = id
        self.key = key
        self.category = category
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.importance = min(max(importance, 0), 1)
        self.personaScope = personaScope
    }

    public enum CodingKeys: String, CodingKey {
        case id, key, category, value, createdAt, updatedAt, metadata, importance, personaScope
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        category = try c.decode(Category.self, forKey: .category)
        value = try c.decode(String.self, forKey: .value)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        let rawImportance = try c.decodeIfPresent(Double.self, forKey: .importance) ?? 0.5
        importance = min(max(rawImportance, 0), 1)
        personaScope = try c.decodeIfPresent(String.self, forKey: .personaScope)
    }
}
