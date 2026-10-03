import Foundation
import Core

extension AIService {
    /// Keychain account for the gateway base URL (https origin only).
    public static let gatewayBaseURLKeychainAccount = "mercury.gateway.baseURL"

    public var hasGatewayBinding: Bool {
        guard let url = KeychainStore.string(forKey: Self.gatewayBaseURLKeychainAccount),
              !url.isEmpty,
              let token = KeychainStore.string(forKey: GatewayAIProvider.deviceTokenKeychainAccount),
              !token.isEmpty else {
            return false
        }
        return (try? GatewayEndpoint(raw: url)) != nil
    }

    /// Bound gateway origin for Codex display (never the token).
    public var gatewayBaseURLDisplay: String? {
        KeychainStore.string(forKey: Self.gatewayBaseURLKeychainAccount)
    }

    /// Validates https (or local http), writes URL + device token to Keychain, rebuilds routing.
    /// Returns `nil` on success, or a `GatewayBindError` describing the failure.
    @discardableResult
    public func configureGateway(baseURL: String, deviceToken: String) -> GatewayBindError? {
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedToken = deviceToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return .emptyToken }
        do {
            _ = try GatewayEndpoint(raw: trimmedURL)
        } catch let error as GatewayEndpointError {
            return .invalidURL(error)
        } catch {
            return .invalidURL(.invalid)
        }
        guard KeychainStore.set(trimmedURL, forKey: Self.gatewayBaseURLKeychainAccount) else {
            logger.error("Keychain write failed for gateway base URL", category: logger.ai)
            return .keychainWriteFailed
        }
        guard KeychainStore.set(trimmedToken, forKey: GatewayAIProvider.deviceTokenKeychainAccount) else {
            KeychainStore.delete(forKey: Self.gatewayBaseURLKeychainAccount)
            logger.error("Keychain write failed for gateway device token", category: logger.ai)
            return .keychainWriteFailed
        }
        rebuildProviders()
        return nil
    }

    public func clearGateway() {
        KeychainStore.delete(forKey: Self.gatewayBaseURLKeychainAccount)
        KeychainStore.delete(forKey: GatewayAIProvider.deviceTokenKeychainAccount)
        rebuildProviders()
        logger.info("Gateway binding cleared", category: logger.ai)
    }

    /// `GET /v1/health` against the bound (or draft) endpoint. No bearer token.
    public func testGatewayHealth(baseURL: String? = nil) async -> Result<GatewayHealth, GatewayBindError> {
        let raw = (baseURL ?? KeychainStore.string(forKey: Self.gatewayBaseURLKeychainAccount))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let endpoint: GatewayEndpoint
        do {
            endpoint = try GatewayEndpoint(raw: raw)
        } catch let error as GatewayEndpointError {
            return .failure(.invalidURL(error))
        } catch {
            return .failure(.invalidURL(.invalid))
        }

        let request = endpoint.healthRequest()
        do {
            let (data, response) = try await gatewayHealthFetcher(request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.healthFailed(status: nil))
            }
            guard (200..<300).contains(http.statusCode) else {
                return .failure(.healthFailed(status: http.statusCode))
            }
            let health = try JSONDecoder().decode(GatewayHealth.self, from: data)
            guard health.isMercury else {
                return .failure(.notMercury)
            }
            return .success(health)
        } catch is DecodingError {
            return .failure(.notMercury)
        } catch {
            return .failure(.healthFailed(status: nil))
        }
    }

    /// Builds a gateway provider when both Keychain values are present and valid.
    static func makeGatewayProvider() -> GatewayAIProvider? {
        guard let raw = KeychainStore.string(forKey: gatewayBaseURLKeychainAccount),
              !raw.isEmpty,
              let endpoint = try? GatewayEndpoint(raw: raw) else {
            return nil
        }
        return GatewayAIProvider.make(endpoint: endpoint)
    }

    public func clearAllAPIKeys() {
        KeychainStore.delete(forKey: Self.grokAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: Self.geminiAPIKeyKeychainAccount)
        KeychainStore.delete(forKey: Self.gatewayBaseURLKeychainAccount)
        KeychainStore.delete(forKey: GatewayAIProvider.deviceTokenKeychainAccount)
        primaryProvider = nil
        secondaryProvider = nil
        logger.info("AI routing cleared: intelligence unbound", category: logger.ai)
    }

    /// Throws `.apiKeyMissing` / `.intelligenceDisabled` when a request would not hit the network.
    /// Used by MercuryBrain offline fast-fail so unbound/disabled guidance wins over airplane mode.
    public func ensureReadyForNetworkRequest() throws {
        guard primaryProvider != nil else {
            logger.info("AI request refused: intelligence unbound", category: logger.ai)
            throw AppError.apiKeyMissing
        }
        guard featureFlags.isEnabled("aiServiceEnabled") else {
            logger.info("AI request refused: intelligence disabled in the Codex", category: logger.ai)
            throw AppError.intelligenceDisabled
        }
    }
}

/// Errors surfaced by Codex bind / test-connection (no provider names in user text).
public enum GatewayBindError: Error, Equatable, Sendable {
    case invalidURL(GatewayEndpointError)
    case emptyToken
    case keychainWriteFailed
    case healthFailed(status: Int?)
    case notMercury

    public var userMessage: String {
        switch self {
        case .invalidURL(.empty):
            return "Enter a gateway URL."
        case .invalidURL(.notHTTPS):
            return "Gateway URL must be https (http only for localhost)."
        case .invalidURL(.missingHost), .invalidURL(.invalid):
            return "Gateway URL is not valid."
        case .invalidURL(.hasUserInfo), .invalidURL(.hasQueryOrFragment), .invalidURL(.tokenInURL):
            return "Gateway URL must be an https origin with no credentials or query."
        case .emptyToken:
            return "Enter a non-empty device token."
        case .keychainWriteFailed:
            return "Could not save the gateway binding to the Keychain."
        case .healthFailed(let status):
            if let status {
                return "Gateway health check failed (HTTP \(status))."
            }
            return "Gateway health check failed."
        case .notMercury:
            return "That endpoint is not a Mercury gateway."
        }
    }
}
