import XCTest
@testable import Core
@testable import Memory

/// Deterministic bag-of-words embedder: one dimension per vocabulary word.
private actor FakeEmbedder: MemoryEmbedder {
    static let vocabulary = ["coffee", "espresso", "swift", "code", "run", "marathon", "dog"]

    var revision: String
    var isAvailable = true
    private(set) var embeddedTexts: [String] = []

    init(revision: String = "fake/r1") {
        self.revision = revision
    }

    func setRevision(_ value: String) { revision = value }
    func setAvailable(_ value: Bool) { isAvailable = value }
    func resetCalls() { embeddedTexts.removeAll() }

    func currentRevision() async -> String? {
        isAvailable ? revision : nil
    }

    func embed(_ text: String) async -> MemoryEmbedding? {
        guard isAvailable else { return nil }
        embeddedTexts.append(text)
        let words = text.lowercased().split { !$0.isLetter }
        var raw = Self.vocabulary.map { word in Double(words.filter { $0 == word }.count) }
        // Synonyms share a direction so ranking is semantic, not literal.
        if words.contains("latte") { raw[0] += 1 }
        raw.append(0.05)
        guard let vector = EmbeddingMath.normalized(raw) else { return nil }
        return MemoryEmbedding(revision: revision, vector: vector)
    }
}

final class EmbeddingIndexTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmbeddingIndexTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private let coffee = MemoryItem(key: "pref.drink", category: .preference, value: "Christopher drinks espresso coffee")
    private let swift = MemoryItem(key: "project.app", category: .project, value: "Mercury is written in Swift code")
    private let running = MemoryItem(key: "note.sport", category: .temporary, value: "Training for a marathon run")

    private var items: [MemoryItem] { [coffee, swift, running] }

    // MARK: - Ranking

    func testSearchRanksMostSimilarMemoryFirst() async {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)

        let result = await index.search("latte", in: items)

        XCTAssertEqual(result.method, .vector(revision: "fake/r1"))
        XCTAssertEqual(result.matches.first?.id, coffee.id)
        XCTAssertEqual(result.matches.count, 3)
        let scores = result.matches.map(\.score)
        XCTAssertEqual(scores, scores.sorted(by: >))
    }

    func testSearchRespectsLimitAndOnlyReturnsGivenItems() async {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)

        let limited = await index.search("swift code", in: items, limit: 1)
        XCTAssertEqual(limited.matches.map(\.id), [swift.id])

        let subset = await index.search("coffee", in: [swift, running])
        XCTAssertFalse(subset.matches.contains { $0.id == coffee.id })
    }

    func testSearchEmbedsMissingItemsLazily() async {
        let embedder = FakeEmbedder()
        let index = EmbeddingIndex(embedder: embedder, directoryURL: directory)

        let result = await index.search("marathon", in: items)

        XCTAssertEqual(result.matches.first?.id, running.id)
        let stored = await index.count
        XCTAssertEqual(stored, 3)
    }

    // MARK: - Persistence + rebuild

    func testSidecarIsReusedWithoutReembedding() async {
        await EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory).rebuild(from: items)

        let embedder = FakeEmbedder()
        let reopened = EmbeddingIndex(embedder: embedder, directoryURL: directory)
        let stored = await reopened.count
        XCTAssertEqual(stored, 3)

        await reopened.rebuild(from: items)
        let calls = await embedder.embeddedTexts
        XCTAssertTrue(calls.isEmpty, "Current vectors must not be re-embedded")
    }

    func testRevisionChangeRebuildsEveryVector() async {
        await EmbeddingIndex(embedder: FakeEmbedder(revision: "fake/r1"), directoryURL: directory).rebuild(from: items)

        let embedder = FakeEmbedder(revision: "fake/r2")
        let index = EmbeddingIndex(embedder: embedder, directoryURL: directory)
        await index.rebuild(from: items)

        let calls = await embedder.embeddedTexts
        XCTAssertEqual(calls.count, 3)
        let revision = await index.currentRevision
        XCTAssertEqual(revision, "fake/r2")

        let reopened = EmbeddingIndex(embedder: FakeEmbedder(revision: "fake/r2"), directoryURL: directory)
        let result = await reopened.search("coffee", in: items)
        XCTAssertEqual(result.method, .vector(revision: "fake/r2"))
        XCTAssertEqual(result.matches.first?.id, coffee.id)
    }

    func testRevisionChangeDuringSearchDropsOldVectors() async {
        let embedder = FakeEmbedder(revision: "fake/r1")
        let index = EmbeddingIndex(embedder: embedder, directoryURL: directory)
        await index.rebuild(from: items)
        await embedder.setRevision("fake/r2")
        await embedder.resetCalls()

        let result = await index.search("swift", in: items)

        XCTAssertEqual(result.method, .vector(revision: "fake/r2"))
        XCTAssertEqual(result.matches.first?.id, swift.id)
        let calls = await embedder.embeddedTexts
        XCTAssertEqual(calls.count, 4, "query + every item re-embedded at the new revision")
    }

    func testEditedMemoryIsReembedded() async {
        let embedder = FakeEmbedder()
        let index = EmbeddingIndex(embedder: embedder, directoryURL: directory)
        await index.rebuild(from: items)
        await embedder.resetCalls()

        var edited = running
        edited.value = "Walking the dog"
        await index.rebuild(from: [coffee, swift, edited])

        let calls = await embedder.embeddedTexts
        XCTAssertEqual(calls.count, 1)
        let result = await index.search("dog", in: [coffee, swift, edited], limit: 1)
        XCTAssertEqual(result.matches.first?.id, edited.id)
    }

    func testCorruptSidecarIsTreatedAsEmpty() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(EmbeddingIndex.fileName)
        try Data("not json".utf8).write(to: fileURL)

        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        let stored = await index.count
        XCTAssertEqual(stored, 0)

        await index.rebuild(from: items)
        let rebuilt = await index.count
        XCTAssertEqual(rebuilt, 3)
    }

    // MARK: - Delete

    func testRemoveDropsVectorFromSidecar() async {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)

        await index.remove(id: coffee.id)

        let reopened = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        let stored = await reopened.count
        XCTAssertEqual(stored, 2)
        let result = await reopened.search("coffee", in: [swift, running])
        XCTAssertFalse(result.matches.contains { $0.id == coffee.id })
    }

    func testRebuildPrunesDeletedMemories() async {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)

        await index.rebuild(from: [swift])

        let stored = await index.count
        XCTAssertEqual(stored, 1)
    }

    func testRemoveAllDeletesSidecarFile() async {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)
        XCTAssertTrue(FileManager.default.fileExists(atPath: index.fileURL.path))

        await index.removeAll()

        XCTAssertFalse(FileManager.default.fileExists(atPath: index.fileURL.path))
        let stored = await index.count
        XCTAssertEqual(stored, 0)
    }

    // MARK: - Fallback + privacy

    func testFallsBackToTermOverlapWithoutModel() async {
        let embedder = FakeEmbedder()
        await embedder.setAvailable(false)
        let index = EmbeddingIndex(embedder: embedder, directoryURL: directory)

        let result = await index.search("marathon training", in: items)

        XCTAssertEqual(result.method, .termOverlap)
        XCTAssertEqual(result.matches.map(\.id), [running.id])
    }

    func testFallbackEmbedderUsesFirstAvailableTier() async {
        let primary = FakeEmbedder(revision: "primary")
        await primary.setAvailable(false)
        let secondary = FakeEmbedder(revision: "secondary")

        let embedding = await FallbackEmbedder([primary, secondary]).embed("coffee")
        XCTAssertEqual(embedding?.revision, "secondary")

        let none = await FallbackEmbedder([primary]).embed("coffee")
        XCTAssertNil(none)
    }

    func testSidecarNeverContainsMemoryText() async throws {
        let index = EmbeddingIndex(embedder: FakeEmbedder(), directoryURL: directory)
        await index.rebuild(from: items)

        let contents = try String(contentsOf: index.fileURL, encoding: .utf8)
        for item in items {
            XCTAssertFalse(contents.contains(item.value))
            XCTAssertFalse(contents.contains(item.key))
        }
        XCTAssertTrue(contents.contains(coffee.id.uuidString))
    }

    // MARK: - Math

    func testMeanPoolAndNormalize() throws {
        let pooled = try XCTUnwrap(EmbeddingMath.meanPool([[1, 0], [3, 4]]))
        XCTAssertEqual(pooled, [2, 2])
        let unit = try XCTUnwrap(EmbeddingMath.normalized(pooled))
        let length = unit.reduce(0) { $0 + Double($1 * $1) }.squareRoot()
        XCTAssertEqual(length, 1, accuracy: 1e-6)

        XCTAssertNil(EmbeddingMath.meanPool([]))
        XCTAssertNil(EmbeddingMath.meanPool([[1, 2], [1]]))
        XCTAssertNil(EmbeddingMath.normalized([0, 0]))
        XCTAssertNil(EmbeddingMath.normalized([.nan, 1]))
    }

    func testCosine() {
        XCTAssertEqual(EmbeddingMath.cosine([1, 0], [1, 0]), 1, accuracy: 1e-9)
        XCTAssertEqual(EmbeddingMath.cosine([1, 0], [0, 1]), 0, accuracy: 1e-9)
        XCTAssertEqual(EmbeddingMath.cosine([1, 0], [-1, 0]), -1, accuracy: 1e-9)
        XCTAssertEqual(EmbeddingMath.cosine([1, 0], [1, 0, 0]), 0)
        XCTAssertEqual(EmbeddingMath.cosine([0, 0], [1, 0]), 0)
    }

    func testOnDeviceInputIsTrimmedAndCapped() {
        XCTAssertNil(OnDeviceEmbedder.prepared("   \n"))
        let long = String(repeating: "a", count: OnDeviceEmbedder.maximumInputCharacters + 50)
        XCTAssertEqual(OnDeviceEmbedder.prepared(long)?.count, OnDeviceEmbedder.maximumInputCharacters)
    }
}
