import CoreSpotlight
import Foundation
import Core

protocol NoteSearchIndexing: Sendable {
    func replaceAll(with notes: [MemoryEntity]) async throws
    func removeAll() async throws
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
public final class NoteSpotlightSync {
    public static let flagKey = "spotlightNotesEnabled"
    public static let maxIndexed = 200

    private struct IndexedNote: Equatable {
        let id: UUID
        let text: String
        let savedAt: Date
        init(_ note: MemoryEntity) {
            id = note.id
            text = note.text
            savedAt = note.savedAt
        }
    }

    private let flags: FeatureFlags
    private let index: NoteSearchIndexing
    private let notes: () -> [MemoryItem]
    private var memoryReady: Bool
    private var queue: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    /// Last successfully indexed note snapshot. nil forces the first opted-in sync.
    private var lastIndexedSnapshot: [IndexedNote]?
    public private(set) var lastError: Error?
    public private(set) var removalFailed = false

    init(
        flags: FeatureFlags,
        index: NoteSearchIndexing,
        waitForMemoryLoad: Bool = false,
        notes: @escaping () -> [MemoryItem]
    ) {
        self.flags = flags
        self.index = index
        self.memoryReady = !waitForMemoryLoad
        self.notes = notes
    }

    public convenience init(
        flags: FeatureFlags,
        surface: IntelligenceSurface,
        waitForMemoryLoad: Bool = false
    ) {
        self.init(flags: flags, index: CoreSpotlightNoteIndex(), surface: surface, waitForMemoryLoad: waitForMemoryLoad)
    }

    convenience init(
        flags: FeatureFlags,
        index: NoteSearchIndexing,
        surface: IntelligenceSurface,
        waitForMemoryLoad: Bool = false
    ) {
        self.init(flags: flags, index: index, waitForMemoryLoad: waitForMemoryLoad) {
            surface.memoryNotes(limit: Self.maxIndexed + 1)
        }
    }

    public var isEnabled: Bool { flags.isEnabled(Self.flagKey) }

    public func setEnabled(_ enabled: Bool) async {
        flags.set(Self.flagKey, enabled: enabled)
        await sync()
    }

    public func memoryDidLoad() async {
        memoryReady = true
        await sync()
    }

    public func memoryLoadSucceeded() async {
        guard !memoryReady else { return }
        await memoryDidLoad()
    }

    /// Conversation updates are ignored unless the saved-note snapshot actually changed.
    /// Snapshot comparison still detects edits, additions and deletions.
    public func follow(_ eventBus: EventBus) {
        followTask?.cancel()
        followTask = Task { [weak self] in
            let stream = await eventBus.events(bufferingNewest: 1) { event in
                if case .memoryDidUpdate = event { return true }
                return false
            }
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                if self.isEnabled || self.removalFailed { await self.sync() }
            }
        }
    }

    public func sync() async {
        let previous = queue
        let task = Task { [weak self] in
            await previous?.value
            await self?.reconcile()
        }
        queue = task
        await task.value
    }

    private func reconcile() async {
        let enabled = isEnabled
        if enabled && !memoryReady { return }
        do {
            if enabled {
                let entities = notes().prefix(Self.maxIndexed).map(MemoryEntity.init)
                let snapshot = entities.map(IndexedNote.init)
                guard snapshot != lastIndexedSnapshot else {
                    lastError = nil
                    removalFailed = false
                    return
                }
                try await index.replaceAll(with: entities)
                lastIndexedSnapshot = snapshot
            } else {
                try await index.removeAll()
                lastIndexedSnapshot = nil
            }
            lastError = nil
            removalFailed = false
        } catch {
            lastError = error
            removalFailed = !enabled
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
struct CoreSpotlightNoteIndex: NoteSearchIndexing {
    static let domain = "com.quicksilver.notes"

    func replaceAll(with notes: [MemoryEntity]) async throws {
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

    func removeAll() async throws {
        try await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [Self.domain])
    }
}

public enum NoteSpotlightRoute {
    public static func noteID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return UUID(uuidString: raw)
    }
}
