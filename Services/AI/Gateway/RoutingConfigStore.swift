import Foundation
import Core
import Synchronization

/// Loads, validates, caches, and refreshes `AIRoutingConfig` (M3-T4).
///
/// Order: valid Application Support cache → bundled default → in-code fallback.
/// `refresh` GETs `/v1/config`; any failure keeps the previous effective config.
/// Never stores or decodes API keys. Cache writes re-encode the validated model
/// so unknown JSON fields (including misspelled secrets) are not persisted.
/// State lives in a `Mutex`, so the type is checked `Sendable` (issue #252).
public final class RoutingConfigStore: Sendable {
    public static let cacheFileName = "ai-routing.cache.json"
    public static let bundledResourceName = "ai-routing.default"

    public typealias BundledLoader = @Sendable () throws -> Data
    public typealias DataFetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private struct State {
        var effective: AIRoutingConfig
        /// Monotonic generation so overlapping refreshes cannot roll back a newer policy.
        var refreshGeneration = 0
    }

    private let state: Mutex<State>
    private let bundledLoader: BundledLoader
    private let cacheDirectoryURL: URL
    private let fetch: DataFetcher

    public init(
        bundledLoader: @escaping BundledLoader = RoutingConfigStore.defaultBundledLoader,
        fileManager: FileManager = .default, // used for launch-time cache reads only
        cacheDirectoryURL: URL? = nil,
        fetch: @escaping DataFetcher = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.bundledLoader = bundledLoader
        self.fetch = fetch

        let resolvedCacheDir: URL
        if let cacheDirectoryURL {
            resolvedCacheDir = cacheDirectoryURL
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.temporaryDirectory
            resolvedCacheDir = appSupport.appendingPathComponent("Mercury", isDirectory: true)
        }
        self.cacheDirectoryURL = resolvedCacheDir

        let bundled = Self.loadBundled(using: bundledLoader)
        if let cached = Self.loadCache(
            directory: resolvedCacheDir,
            fileManager: fileManager
        ) {
            self.state = Mutex(State(effective: cached))
        } else {
            self.state = Mutex(State(effective: bundled))
        }
    }

    /// Current effective config (cache if valid, else bundled).
    public func loadValidated() -> AIRoutingConfig {
        state.withLock { $0.effective }
    }

    /// `GET /v1/config` with bearer token. On success validates and writes the cache.
    /// On any error keeps the previous effective config (never throws to callers).
    @discardableResult
    public func refresh(from endpoint: GatewayEndpoint, deviceToken: String) async -> Bool {
        let generation = beginRefresh()
        do {
            var request = try endpoint.authorizedRequest(
                path: "v1/config",
                deviceToken: deviceToken,
                method: "GET"
            )
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await fetch(request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return false
            }
            // Privacy floor: remote config may tighten, never loosen, the compiled-in policy.
            let config = try AIRoutingConfig.decodeAndValidate(data).clampedToPrivacyFloor()
            let encoded = try config.encodeForCache()
            // Write + publish under one generation check so an older refresh
            // cannot clobber a newer cache after losing the publish race.
            return try commitIfCurrent(generation, config: config, encoded: encoded)
        } catch {
            return false
        }
    }

    public var cacheFileURL: URL {
        cacheDirectoryURL.appendingPathComponent(Self.cacheFileName)
    }

    // MARK: - Sync lock helpers (never hold the lock across an await)

    private func beginRefresh() -> Int {
        state.withLock { state in
            state.refreshGeneration += 1
            return state.refreshGeneration
        }
    }

    private func commitIfCurrent(
        _ generation: Int,
        config: AIRoutingConfig,
        encoded: Data
    ) throws -> Bool {
        try state.withLock { state in
            guard generation == state.refreshGeneration else { return false }
            // FileManager.default (thread-safe) rather than a stored non-Sendable instance.
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
                try fileManager.createDirectory(
                    at: cacheDirectoryURL,
                    withIntermediateDirectories: true
                )
            }
            try encoded.write(to: cacheFileURL, options: [.atomic])
            state.effective = config
            return true
        }
    }

    // MARK: - Loaders

    public static func defaultBundledLoader() throws -> Data {
        if let url = Bundle.main.url(
            forResource: bundledResourceName,
            withExtension: "json"
        ) {
            return try Data(contentsOf: url)
        }
        return Data(AIRoutingConfig.bundledDefaultJSON.utf8)
    }

    private static func loadBundled(using loader: BundledLoader) -> AIRoutingConfig {
        if let data = try? loader(),
           let config = try? AIRoutingConfig.decodeAndValidate(data) {
            return config
        }
        return .bundledDefault
    }

    private static func loadCache(
        directory: URL,
        fileManager: FileManager
    ) -> AIRoutingConfig? {
        let url = directory.appendingPathComponent(cacheFileName)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? AIRoutingConfig.decodeAndValidate(data) else {
            return nil
        }
        // A cache written before the floor existed is clamped too.
        return config.clampedToPrivacyFloor()
    }

}

extension AIRoutingConfig {
    /// Map routing timeouts onto the gateway SSE client budget.
    public var gatewayTimeouts: GatewayTimeouts {
        GatewayTimeouts(
            connect: timeouts.connect,
            firstEvent: timeouts.firstEvent,
            idle: timeouts.idle,
            total: timeouts.total
        )
    }
}
