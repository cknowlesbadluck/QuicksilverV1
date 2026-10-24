import CoreSpotlight
import Foundation
import Core

/// Where saved notes are indexed for system search. Internal: only the app's own CoreSpotlight
/// index and test fakes conform, so no other module can receive note text through it.
protocol NoteSearchIndexing: Sendable {
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
    /// False until the first memory load finishes (production). While false an enabled sync
    /// is skipped, so an empty, not-yet-loaded snapshot never replaces the index.
    private var memoryReady: Bool
    /// Tail of the serialized reconcile chain (see `sync()`).
    private var queue: Task<Void, Never>?
    private var followTask: Task<Void, Never>?
    public private(set) var lastError: Error?
    /// True when the user turned Spotlight off but removing indexed notes failed. The UI must
    /// say so; the next sync (app activation, memory change or toggle) retries the removal.
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

    /// Production wiring: CoreSpotlight, with notes only from `IntelligenceSurface.memoryNotes`.
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

    /// Call once the initial memory load has finished, then the index is reconciled.
    public func memoryDidLoad() async {
        memoryReady = true
        await sync()
    }

    /// Re-syncs after every note save, edit or delete while opted in, so a deleted note does
    /// not linger in Spotlight until the next app activation.
    public func follow(_ eventBus: EventBus) {
        followTask?.cancel()
        followTask = Task { [weak self] in
            let stream = await eventBus.events(bufferingNewest: 1) { event in
                if case .memoryDidUpdate = event { return true }
                return false
            }
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                if self.isEnabled { await self.sync() }
            }
        }
    }

    /// Brings the index in line with the flag. Never throws; the last failure is kept for the UI.
    /// Calls are serialized and each one reads the flag when it runs, so a fast on → off can
    /// never finish with notes still indexed.
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
                try await index.replaceAll(with: notes().prefix(Self.maxIndexed).map(MemoryEntity.init))
            } else {
                try await index.removeAll()
            }
            lastError = nil
            removalFailed = false
        } catch {
            lastError = error
            removalFailed = !enabled
        }
    }
}

/// CoreSpotlight-backed index. Items live in one domain so opt-out can remove them all at once.
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

/// Routes a Spotlight result tap back to its note. Only `CSSearchableItemActionType` activities
/// carrying a UUID identifier are accepted, because the index only ever holds note IDs (see
/// `CoreSpotlightNoteIndex`), so anything else is ignored.
public enum NoteSpotlightRoute {
    public static func noteID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == CSSearchableItemActionType,
              let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String
        else { return nil }
        return UUID(uuidString: raw)
    }
}
