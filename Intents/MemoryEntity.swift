import AppIntents
import Foundation
import Core

/// A saved user note as an App Intents entity (M3.5-T11). Only notes are exposed,
/// never chat turns. Values come from `IntelligenceSurface` only.
@available(iOS 17.0, macOS 14.0, *)
public struct MemoryEntity: AppEntity, Sendable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Memory")
    public static let defaultQuery = MemoryEntityQuery()

    public var id: UUID
    public var text: String
    public var savedAt: Date

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(Self.title(for: text))", subtitle: "Saved note")
    }

    public init(id: UUID, text: String, savedAt: Date) {
        self.id = id
        self.text = text
        self.savedAt = savedAt
    }

    init(_ item: MemoryItem) {
        self.init(id: item.id, text: item.value, savedAt: item.updatedAt)
    }

    /// First line, at most 60 characters, for list rows.
    static func title(for text: String) -> String {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        return firstLine.count > 60 ? String(firstLine.prefix(59)) + "…" : firstLine
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct MemoryEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [UUID]) async throws -> [MemoryEntity] {
        try await MainActor.run {
            let surface = try IntentDependencies.shared.requireSurface()
            return identifiers.compactMap { surface.memoryNote(id: $0).map(MemoryEntity.init) }
        }
    }

    public func entities(matching string: String) async throws -> [MemoryEntity] {
        try await MainActor.run {
            try IntentDependencies.shared.requireSurface().memoryNotes(matching: string).map(MemoryEntity.init)
        }
    }

    public func suggestedEntities() async throws -> [MemoryEntity] {
        try await MainActor.run {
            try IntentDependencies.shared.requireSurface().memoryNotes(limit: 10).map(MemoryEntity.init)
        }
    }
}
