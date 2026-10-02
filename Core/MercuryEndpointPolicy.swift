import Foundation

/// Fail-closed gate for any Mercury or provider URL before a request is built.
///
/// The policy is pure. It does not open a socket and it does not read Keychain.
/// A URL is allowed only when it is HTTPS, has a host, carries no userinfo, and
/// does not target loopback, link-local, private, or mDNS space.
public struct MercuryEndpointPolicy: Sendable {
    public init() {}

    public func evaluate(_ raw: String) -> MercuryEndpointVerdict {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .refuse(.empty)
        }
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased() else {
            return .refuse(.unparseable)
        }
        guard scheme == "https" else {
            return .refuse(.notHTTPS)
        }
        if components.user != nil || components.password != nil {
            return .refuse(.userinfo)
        }
        guard let host = components.host?.lowercased(), !host.isEmpty else {
            return .refuse(.missingHost)
        }
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return .refuse(.loopback)
        }
        if let refusal = Self.addressRefusal(host) {
            return .refuse(refusal)
        }
        return .allow
    }

    private static func addressRefusal(_ host: String) -> MercuryEndpointRefusal? {
        let bare = host.hasPrefix("[") && host.hasSuffix("]")
            ? String(host.dropFirst().dropLast())
            : host
        if bare == "::1" || bare == "0:0:0:0:0:0:0:1" {
            return .loopback
        }
        if bare.hasPrefix("fe80:") {
            return .linkLocal
        }
        let parts = bare.split(separator: ".")
        let octets = parts.compactMap { UInt8($0) }
        guard octets.count == 4, parts.count == 4 else {
            return nil
        }
        if octets[0] == 127 || octets == [0, 0, 0, 0] {
            return .loopback
        }
        if octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) {
            return .privateAddress
        }
        if octets[0] == 172 && (16...31).contains(octets[1]) {
            return .privateAddress
        }
        if octets[0] == 169 && octets[1] == 254 {
            return .linkLocal
        }
        return nil
    }
}

public enum MercuryEndpointDecision: String, Sendable, Equatable {
    case allow
    case refuse
}

public enum MercuryEndpointRefusal: String, Sendable, Equatable {
    case empty
    case unparseable
    case notHTTPS
    case userinfo
    case missingHost
    case loopback
    case privateAddress
    case linkLocal
}

public struct MercuryEndpointVerdict: Sendable, Equatable {
    public let decision: MercuryEndpointDecision
    public let refusal: MercuryEndpointRefusal?

    public static let allow = MercuryEndpointVerdict(decision: .allow, refusal: nil)

    public static func refuse(_ refusal: MercuryEndpointRefusal) -> MercuryEndpointVerdict {
        MercuryEndpointVerdict(decision: .refuse, refusal: refusal)
    }
}
