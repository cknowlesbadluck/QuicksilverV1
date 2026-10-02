import Foundation

/// Bind target for the owner-owned Mercury gateway (M3).
/// Provider keys stay on the gateway. The device token stays in the Authorization header.
/// Neither is allowed in this URL.
public struct GatewayEndpoint: Equatable, Sendable {
    public let url: URL

    public init(raw: String) throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GatewayEndpointError.empty }
        guard let components = URLComponents(string: trimmed), components.url != nil else {
            throw GatewayEndpointError.invalid
        }
        guard let scheme = components.scheme?.lowercased() else {
            throw GatewayEndpointError.notHTTPS
        }
        let host = components.host ?? ""
        guard !host.isEmpty else { throw GatewayEndpointError.missingHost }
        let local = host == "localhost" || host == "127.0.0.1"
        if scheme != "https" {
            guard scheme == "http", local else { throw GatewayEndpointError.notHTTPS }
        }
        if components.user != nil || components.password != nil {
            throw GatewayEndpointError.hasUserInfo
        }
        if components.query != nil || components.fragment != nil {
            throw GatewayEndpointError.hasQueryOrFragment
        }
        var clean = URLComponents()
        clean.scheme = scheme
        clean.host = host
        clean.port = components.port
        guard let normalized = clean.url else { throw GatewayEndpointError.invalid }
        self.url = normalized
    }

    /// `GET /v1/health`. No token. No cache. Matches the Workers scaffold.
    public func healthRequest() -> URLRequest {
        var request = URLRequest(url: url.appending(path: "v1/health"))
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    /// Bearer token only. Rejects an empty token and any path that tries to smuggle a query.
    public func authorizedRequest(path: String, deviceToken: String) throws -> URLRequest {
        let relative = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !deviceToken.isEmpty,
              !deviceToken.contains(where: \.isWhitespace),
              !relative.contains("?"),
              !relative.contains("#")
        else {
            throw GatewayEndpointError.tokenInURL
        }
        var request = URLRequest(url: url.appending(path: relative))
        request.httpMethod = "POST"
        request.setValue("Bearer \(deviceToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

public struct GatewayHealth: Decodable, Equatable, Sendable {
    public let ok: Bool
    public let service: String

    public var isMercury: Bool {
        ok && service == "mercury-gateway"
    }
}

public enum GatewayEndpointError: Error, Equatable, Sendable {
    case empty
    case invalid
    case notHTTPS
    case missingHost
    case hasUserInfo
    case hasQueryOrFragment
    case tokenInURL
}
