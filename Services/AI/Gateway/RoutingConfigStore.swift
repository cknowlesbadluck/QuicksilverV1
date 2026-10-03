import Foundation
import Core

/// Loads, validates, caches, and refreshes `AIRoutingConfig` (M3-T4).
///
/// Order: valid Application Support cache → bundled default → in-code fallback.
/// `refresh` GETs `/v1/config`; any failure keeps the previous effective config.
/// Never stores or decodes API keys.
public final class RoutingConfigStore: @unchecked Sendable {
    public static let cacheFileName = "ai-routing.cache.json"
    public static let bundledResourceName = "ai-routing.default"

    public typealias BundledLoader = @Sendable () throws -> Data
    public typealias DataFetcher = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private let lock = NSLock()
    private var effective: AIRoutingConfig
    private let bundledLoader: BundledLoader
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL
    private let fetch: DataFetcher

    public init(
        bundledLoader: @escaping BundledLoader = RoutingConfigStore.defaultBundledLoader,
        fileManager: FileManager = .default,
        cacheDirectoryURL: URL? = nil,
        fetch: @escaping DataFetcher = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.bundledLoader = bundledLoader
        self.fileManager = fileManager
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
            self.effective = cached
        } else {
            self.effective = bundled
        }
    }

    /// Current effective config (cache if valid, else bundled).
    public func loadValidated() -> AIRoutingConfig {
        lock.lock()
        defer { lock.unlock() }
        return effective
    }

    /// `GET /v1/config` with bearer token. On success validates and writes the cache.
    /// On any error keeps the previous effective config (never throws to callers).
    @discardableResult
    public func refresh(from endpoint: GatewayEndpoint, deviceToken: String) async -> Bool {
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
            let config = try AIRoutingConfig.decodeAndValidate(data)
            try writeCache(data)
            publish(config)
            return true
        } catch {
            return false
        }
    }

    public var cacheFileURL: URL {
        cacheDirectoryURL.appendingPathComponent(Self.cacheFileName)
    }

    /// Sync helper so `NSLock` is never touched directly from an `async` function body.
    private func publish(_ config: AIRoutingConfig) {
        lock.lock()
        effective = config
        lock.unlock()
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
        return config
    }

    private func writeCache(_ data: Data) throws {
        if !fileManager.fileExists(atPath: cacheDirectoryURL.path) {
            try fileManager.createDirectory(
                at: cacheDirectoryURL,
                withIntermediateDirectories: true
            )
        }
        try data.write(to: cacheFileURL, options: [.atomic])
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
