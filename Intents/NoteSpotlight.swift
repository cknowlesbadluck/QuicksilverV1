import CoreSpotlight
import Foundation
import Core

/// Where saved notes are indexed for system search. Faked in tests.
public protocol NoteSearchIndexing: Sendable {
    func replaceAll(with notes: [MemoryEntity]) async throws
    func removeAll() async throws
}

/// Spotlight opt-in for saved notes (M3.5-T9). **Off by default.** Only notes (never chat turns)
/// are indexed, only while the user has opted in, and turning it off removes every indexed note.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class NoteSpotlightSync {
    public static let flagKey = "spotlightNotesEnabled"
    /// Upper bound on indexed notes, so a large memory never floods Spotlight.
    public static let maxIndexed = 200

    private let flags: FeatureFlags
    private let index: NoteSearchIndexing
    private let notes: () -> [MemoryItem]
    public private(set) var lastError: Error?

    public init(flags: FeatureFlags, index: NoteSearchIndexing, notes: @escaping () -> [MemoryItem]) {
        self.flags = flags
        self.index = index
        self.notes = notes
    }

    /// Production wiring: notes come only from `IntelligenceSurface.memoryNotes`, never chat turns.
    public convenience init(
        flags: FeatureFlags,
        index: NoteSearchIndexing = CoreSpotlightNoteIndex(),
        surface: IntelligenceSurface
    ) {
        self.init(flags: flags, index: index) { surface.memoryNotes(limit: Self.maxIndexed + 1) }
    }

    public var isEnabled: Bool { flags.isEnabled(Self.flagKey) }

    public func setEnabled(_ enabled: Bool) async {
        flags.set(Self.flagKey, enabled: enabled)
        await sync()
    }

    /// Brings the index in line with the flag. Never throws; the last failure is kept for the UI.
    public func sync() async {
        do {
            if isEnabled {
                try await index.replaceAll(with: notes().prefix(Self.maxIndexed).map(MemoryEntity.init))
            } else {
                try await index.removeAll()
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }
}

/// CoreSpotlight-backed index. Items live in one domain so opt-out can remove them all at once.
@available(iOS 17.0, macOS 14.0, *)
public struct CoreSpotlightNoteIndex: NoteSearchIndexing {
    public static let domain = "com.quicksilver.notes"

    public init() {}

    public func replaceAll(with notes: [MemoryEntity]) async throws {
        let index = CSSearchableIndex.default()
        try await index.deleteSearchableItems(withDomainIdentifiers: [Self.domain])
        let items = notes.map { note in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = MemoryEntity.title(for: note.text)
            attributes.contentDescription = note.text
            attributes.contentModificationDate = note.savedAt
            return CSSearchableItem(
                uniqueIdentifier: note.id.uuidString, domainIdentifier: Self.domain, attributeSet: attributes
            )
        }
        guard !items.isEmpty else { return }
        try await index.indexSearchableItems(items)
    }

    public func removeAll() async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.domain])
    }
}
