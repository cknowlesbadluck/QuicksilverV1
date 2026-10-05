import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// One on-device vector for a piece of memory text (M3-T13).
///
/// `revision` names the model that produced `vector` (model id, model revision,
/// dimension). Vectors with different revisions are never compared; the index
/// rebuilds instead. `vector` is mean-pooled and L2-normalized.
public struct MemoryEmbedding: Sendable, Equatable {
    public let revision: String
    public let vector: [Float]

    public init(revision: String, vector: [Float]) {
        self.revision = revision
        self.vector = vector
    }
}

/// Turns memory text into vectors on device. Implementations never touch the network
/// with memory content and never log it. Returning `nil` means "no vector model
/// available for this text"; callers fall back to term overlap.
public protocol MemoryEmbedder: Sendable {
    /// Revision `embed` would produce right now, or `nil` when no model is available.
    /// The index compares it with stored vectors to decide when to rebuild.
    func currentRevision() async -> String?
    func embed(_ text: String) async -> MemoryEmbedding?
}

/// Pure vector helpers shared by embedders and the index.
public enum EmbeddingMath {

    /// Average of equally sized token vectors. `nil` when empty, ragged or non-finite.
    public static func meanPool(_ vectors: [[Double]]) -> [Double]? {
        guard let dimension = vectors.first?.count, dimension > 0 else { return nil }
        var sum = [Double](repeating: 0, count: dimension)
        for vector in vectors {
            guard vector.count == dimension else { return nil }
            for index in 0..<dimension {
                sum[index] += vector[index]
            }
        }
        let count = Double(vectors.count)
        let mean = sum.map { $0 / count }
        return mean.allSatisfy(\.isFinite) ? mean : nil
    }

    /// Unit-length copy of `vector`. `nil` for empty, zero or non-finite input.
    public static func normalized(_ vector: [Double]) -> [Float]? {
        guard !vector.isEmpty, vector.allSatisfy(\.isFinite) else { return nil }
        let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard norm > 0, norm.isFinite else { return nil }
        return vector.map { Float($0 / norm) }
    }

    /// Cosine similarity in -1 ... 1. Zero when dimensions differ or a vector is zero.
    public static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0
        for index in 0..<lhs.count {
            let left = Double(lhs[index])
            let right = Double(rhs[index])
            dot += left * right
            lhsNorm += left * left
            rhsNorm += right * right
        }
        let denominator = lhsNorm.squareRoot() * rhsNorm.squareRoot()
        guard denominator > 0, denominator.isFinite else { return 0 }
        return min(max(dot / denominator, -1), 1)
    }
}

/// Uses the first embedder in the chain that has a model, so every vector in one
/// session comes from the same tier. The default chain is contextual → sentence;
/// no available tier means `nil` (callers use term overlap).
public struct FallbackEmbedder: MemoryEmbedder {
    private let chain: [any MemoryEmbedder]

    public init(_ chain: [any MemoryEmbedder]) {
        self.chain = chain
    }

    /// Revision of the first tier with a model, or `nil` when none has one.
    public func currentRevision() async -> String? {
        await activeEmbedder()?.revision
    }

    /// Embeds with the first tier that has a model.
    public func embed(_ text: String) async -> MemoryEmbedding? {
        await activeEmbedder()?.embedder.embed(text)
    }

    private func activeEmbedder() async -> (embedder: any MemoryEmbedder, revision: String)? {
        for embedder in chain {
            if let revision = await embedder.currentRevision() {
                return (embedder, revision)
            }
        }
        return nil
    }
}

/// Factory for the production on-device embedding chain.
public enum OnDeviceEmbedder {
    /// Input cap so very long memories cannot stall the model.
    public static let maximumInputCharacters = 2_000

    /// `NLContextualEmbedding` → `NLEmbedding.sentenceEmbedding(for: .english)` → `nil` (term overlap).
    public static func makeDefault() -> any MemoryEmbedder {
        #if canImport(NaturalLanguage)
        return FallbackEmbedder([ContextualEmbedder(), SentenceEmbedder()])
        #else
        return FallbackEmbedder([])
        #endif
    }

    /// Trimmed, length-capped input, or `nil` for blank text.
    static func prepared(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maximumInputCharacters))
    }
}

#if canImport(NaturalLanguage)

/// `NLContextualEmbedding` (iOS 17+), token vectors mean-pooled and L2-normalized.
/// Model assets are requested once through `requestAssets`; if they are unavailable
/// the embedder returns `nil` for the rest of the session so the chain falls back.
public actor ContextualEmbedder: MemoryEmbedder {
    private enum State {
        case unprepared
        case ready(NLContextualEmbedding, revision: String)
        case unavailable
    }

    private let language: NLLanguage
    private let allowsAssetRequest: Bool
    private var state: State = .unprepared
    /// Actor re-entrancy guard: callers that arrive during the asset request wait for it.
    private var isPreparing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    public init(language: NLLanguage = .english, allowsAssetRequest: Bool = true) {
        self.language = language
        self.allowsAssetRequest = allowsAssetRequest
    }

    /// Loads the model (requesting assets if needed) and returns its revision.
    public func currentRevision() async -> String? {
        await prepare()?.revision
    }

    /// Mean-pooled, L2-normalized contextual vector for `text`.
    public func embed(_ text: String) async -> MemoryEmbedding? {
        guard let input = OnDeviceEmbedder.prepared(text) else { return nil }
        guard let loaded = await prepare(),
              let result = try? loaded.model.embeddingResult(for: input, language: language) else { return nil }

        var tokens: [[Double]] = []
        let source = result.string
        result.enumerateTokenVectors(in: source.startIndex..<source.endIndex) { vector, _ in
            tokens.append(vector)
            return true
        }
        guard let pooled = EmbeddingMath.meanPool(tokens),
              let vector = EmbeddingMath.normalized(pooled) else { return nil }
        return MemoryEmbedding(revision: loaded.revision, vector: vector)
    }

    private func prepare() async -> (model: NLContextualEmbedding, revision: String)? {
        switch state {
        case let .ready(model, revision):
            return (model, revision)
        case .unavailable:
            return nil
        case .unprepared:
            break
        }
        if isPreparing {
            await withCheckedContinuation { waiters.append($0) }
            return await prepare()
        }
        isPreparing = true
        defer {
            isPreparing = false
            let pending = waiters
            waiters.removeAll()
            pending.forEach { $0.resume() }
        }

        guard let model = NLContextualEmbedding(language: language) else {
            state = .unavailable
            return nil
        }
        if !model.hasAvailableAssets {
            guard allowsAssetRequest, await requestAssets(for: model) else {
                state = .unavailable
                return nil
            }
        }
        do {
            try model.load()
        } catch {
            state = .unavailable
            return nil
        }
        let revision = "nl.contextual/\(model.modelIdentifier)/r\(model.revision)/d\(model.dimension)"
        state = .ready(model, revision: revision)
        return (model, revision)
    }

    /// The OS downloads the model assets; no memory text is involved.
    private func requestAssets(for model: NLContextualEmbedding) async -> Bool {
        await withCheckedContinuation { continuation in
            // @Sendable: the framework calls back on its own queue, not this actor.
            model.requestAssets { @Sendable result, _ in
                continuation.resume(returning: result == .available)
            }
        }
    }
}

/// `NLEmbedding.sentenceEmbedding(for:)` fallback, L2-normalized.
public actor SentenceEmbedder: MemoryEmbedder {
    private enum State {
        case unprepared
        case ready(NLEmbedding, revision: String)
        case unavailable
    }

    private let language: NLLanguage
    private var state: State = .unprepared

    public init(language: NLLanguage = .english) {
        self.language = language
    }

    /// Revision of the sentence embedding, or `nil` when the OS has none for the language.
    public func currentRevision() async -> String? {
        prepare()?.revision
    }

    /// L2-normalized sentence vector for `text`.
    public func embed(_ text: String) async -> MemoryEmbedding? {
        guard let input = OnDeviceEmbedder.prepared(text) else { return nil }
        guard let loaded = prepare(),
              let raw = loaded.model.vector(for: input),
              let vector = EmbeddingMath.normalized(raw) else { return nil }
        return MemoryEmbedding(revision: loaded.revision, vector: vector)
    }

    private func prepare() -> (model: NLEmbedding, revision: String)? {
        switch state {
        case let .ready(model, revision):
            return (model, revision)
        case .unavailable:
            return nil
        case .unprepared:
            guard let model = NLEmbedding.sentenceEmbedding(for: language) else {
                state = .unavailable
                return nil
            }
            let revision = "nl.sentence/\(language.rawValue)/r\(model.revision)/d\(model.dimension)"
            state = .ready(model, revision: revision)
            return (model, revision)
        }
    }
}

#endif
