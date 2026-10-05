import Foundation
import Core

/// Rebuildable on-device vector index over memories (M3-T13).
///
/// Vectors live in a sidecar JSON file in Application Support, keyed by memory id and
/// embedding revision, so SwiftData's schema is untouched. The sidecar stores only
/// vectors, the revision and a content fingerprint (never memory text), is excluded
/// from backup, and can be deleted at any time: stale or missing vectors are
/// re-embedded on the next `rebuild` or `search`. Search is brute-force cosine,
/// which is fine at the memory cap. When the embedder has no model it falls back to
/// term overlap. Nothing here touches the network or logs memory content.
public actor EmbeddingIndex {
    public static let fileName = "memory-embeddings.v1.json"
    static let formatVersion = 1

    public enum Method: Sendable, Equatable {
        case vector(revision: String)
        case termOverlap
    }

    public struct Match: Sendable, Equatable {
        public let id: UUID
        public let score: Double

        public init(id: UUID, score: Double) {
            self.id = id
            self.score = score
        }
    }

    public struct SearchResult: Sendable, Equatable {
        public let method: Method
        public let matches: [Match]
    }

    struct Entry: Codable, Equatable, Sendable {
        var revision: String
        var fingerprint: String
        var vector: [Float]
    }

    struct Sidecar: Codable, Sendable {
        var format: Int
        var revision: String?
        var entries: [String: Entry]
    }

    public nonisolated let fileURL: URL
    private let embedder: any MemoryEmbedder
    private var revision: String?
    private var entries: [UUID: Entry] = [:]
    private var isLoaded = false

    /// - Parameter directoryURL: sidecar directory; defaults to `Application Support/Mercury`.
    public init(
        embedder: any MemoryEmbedder = OnDeviceEmbedder.makeDefault(),
        directoryURL: URL? = nil
    ) {
        self.embedder = embedder
        let directory = directoryURL ?? Self.defaultDirectory()
        self.fileURL = directory.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    /// Number of stored vectors (any revision).
    public var count: Int {
        loadIfNeeded()
        return entries.count
    }

    /// Revision of the vectors currently kept, if any.
    public var currentRevision: String? {
        loadIfNeeded()
        return revision
    }

    /// Embeds one memory (no-op when its vector is already current).
    public func upsert(_ item: MemoryItem) async {
        loadIfNeeded()
        await syncRevision()
        let text = Self.text(for: item)
        let fingerprint = Self.fingerprint(text)
        if let entry = entries[item.id], entry.revision == revision, entry.fingerprint == fingerprint {
            return
        }
        guard let embedding = await embedder.embed(text) else {
            if entries.removeValue(forKey: item.id) != nil { save() }
            return
        }
        adopt(embedding.revision)
        entries[item.id] = Entry(revision: embedding.revision, fingerprint: fingerprint, vector: embedding.vector)
        save()
    }

    /// Drops the vector for a deleted memory.
    public func remove(id: UUID) {
        loadIfNeeded()
        guard entries.removeValue(forKey: id) != nil else { return }
        save()
    }

    /// Drops every vector and the sidecar file.
    public func removeAll() {
        entries.removeAll()
        revision = nil
        isLoaded = true
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Brings the sidecar in line with `items`: prunes vectors for memories that no longer
    /// exist and re-embeds missing, edited or old-revision ones.
    public func rebuild(from items: [MemoryItem]) async {
        loadIfNeeded()
        await syncRevision()
        let liveIDs = Set(items.map(\.id))
        var changed = false
        for id in entries.keys where !liveIDs.contains(id) {
            entries.removeValue(forKey: id)
            changed = true
        }
        for item in Self.unique(items) {
            let text = Self.text(for: item)
            let fingerprint = Self.fingerprint(text)
            if let entry = entries[item.id], entry.revision == revision, entry.fingerprint == fingerprint {
                continue
            }
            guard let embedding = await embedder.embed(text) else {
                if entries.removeValue(forKey: item.id) != nil { changed = true }
                continue
            }
            adopt(embedding.revision)
            entries[item.id] = Entry(revision: embedding.revision, fingerprint: fingerprint, vector: embedding.vector)
            changed = true
        }
        if changed { save() }
    }

    /// Ranks `items` against `query` by cosine similarity (best first).
    /// Only ids in `items` can match, so deleted memories never surface.
    /// Falls back to term overlap when no vector model is available.
    public func search(_ query: String, in items: [MemoryItem], limit: Int? = nil) async -> SearchResult {
        loadIfNeeded()
        let candidates = Self.unique(items)
        guard let queryEmbedding = await embedder.embed(query) else {
            return Self.termOverlap(query, in: candidates, limit: limit)
        }
        let queryRevision = queryEmbedding.revision
        adopt(queryRevision)

        var scored: [Match] = []
        var changed = false
        for item in candidates {
            let text = Self.text(for: item)
            let fingerprint = Self.fingerprint(text)
            var vector: [Float]?
            if let entry = entries[item.id], entry.revision == queryRevision, entry.fingerprint == fingerprint {
                vector = entry.vector
            } else if let embedding = await embedder.embed(text), embedding.revision == queryRevision {
                entries[item.id] = Entry(revision: queryRevision, fingerprint: fingerprint, vector: embedding.vector)
                vector = embedding.vector
                changed = true
            }
            guard let vector else { continue }
            scored.append(Match(id: item.id, score: EmbeddingMath.cosine(queryEmbedding.vector, vector)))
        }
        if changed { save() }
        return SearchResult(method: .vector(revision: queryRevision), matches: Self.ranked(scored, limit: limit))
    }

    // MARK: - Revision

    /// A new embedding revision invalidates every vector from other revisions.
    private func adopt(_ newRevision: String) {
        guard newRevision != revision else { return }
        revision = newRevision
        entries = entries.filter { $0.value.revision == newRevision }
        save()
    }

    /// Adopts the embedder's model revision. With no model available the stored
    /// vectors are kept (the model may come back) and simply go unused.
    private func syncRevision() async {
        if let current = await embedder.currentRevision() {
            adopt(current)
        }
    }

    // MARK: - Text

    /// What gets embedded: the memory key (separators as spaces) and its value.
    static func text(for item: MemoryItem) -> String {
        let key = item.key.map { "._-".contains($0) ? " " : String($0) }.joined()
        return key + ": " + item.value
    }

    /// Stable FNV-1a 64-bit hash, so edits trigger a re-embed without storing the text.
    static func fingerprint(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(hash, radix: 16)
    }

    private static func unique(_ items: [MemoryItem]) -> [MemoryItem] {
        var seen = Set<UUID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private static func ranked(_ matches: [Match], limit: Int?) -> [Match] {
        let sorted = matches.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard let limit, limit >= 0 else { return sorted }
        return Array(sorted.prefix(limit))
    }

    private static func termOverlap(_ query: String, in items: [MemoryItem], limit: Int?) -> SearchResult {
        let tokens = MemoryQuery.tokens(from: query)
        let matches = items.compactMap { item -> Match? in
            let score = MemoryQuery.overlap(item, tokens: tokens)
            return score > 0 ? Match(id: item.id, score: score) : nil
        }
        return SearchResult(method: .termOverlap, matches: ranked(matches, limit: limit))
    }

    // MARK: - Sidecar file

    private static func defaultDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("Mercury", isDirectory: true)
    }

    /// Reads the sidecar once. A missing, corrupt or old-format file means an empty index.
    private func loadIfNeeded() {
        guard !isLoaded else { return }
        isLoaded = true
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let sidecar = try? JSONDecoder().decode(Sidecar.self, from: data),
              sidecar.format == Self.formatVersion else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        revision = sidecar.revision
        for (key, entry) in sidecar.entries {
            guard let id = UUID(uuidString: key),
                  entry.revision == sidecar.revision,
                  !entry.vector.isEmpty,
                  entry.vector.allSatisfy(\.isFinite) else { continue }
            entries[id] = entry
        }
    }

    /// Best-effort write; failures only cost a rebuild later.
    private func save() {
        let sidecar = Sidecar(
            format: Self.formatVersion,
            revision: revision,
            entries: Dictionary(uniqueKeysWithValues: entries.map { ($0.key.uuidString, $0.value) })
        )
        guard let data = try? JSONEncoder().encode(sidecar) else { return }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: Self.writeOptions)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = fileURL
            try url.setResourceValues(values)
        } catch {
            return
        }
    }

    private static var writeOptions: Data.WritingOptions {
        #if os(iOS)
        return [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        #else
        return [.atomic]
        #endif
    }
}
