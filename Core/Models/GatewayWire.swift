import Foundation

/// Mercury Gateway wire protocol v1.
///
/// Auth is `Authorization: Bearer <device token>`. A token in the query string,
/// fragment, or userinfo is a protocol violation and must be rejected before any
/// request is sent. Context blocks are kind-tagged. Successful streams are
/// `meta` → zero or more `delta` → `done`. Failures are a single `error` event.
public enum GatewayContextKind: String, Codable, Sendable, CaseIterable {
    case history
    case summary
    case memory
    case device
}

public enum GatewayPrivacy: String, Codable, Sendable, CaseIterable {
    case device
    case ephemeral
    case cloud
}

public struct GatewayMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct GatewayContextBlock: Codable, Sendable, Equatable {
    public let kind: GatewayContextKind
    public let text: String
    public let privacy: GatewayPrivacy

    public init(kind: GatewayContextKind, text: String, privacy: GatewayPrivacy) {
        self.kind = kind
        self.text = text
        self.privacy = privacy
    }
}

public struct GatewayChatRequest: Codable, Sendable, Equatable {
    public let taskTier: String
    public let messages: [GatewayMessage]
    public let context: [GatewayContextBlock]
    public let privacy: GatewayPrivacy
    public let maxTokens: Int

    public init(
        taskTier: String,
        messages: [GatewayMessage],
        context: [GatewayContextBlock],
        privacy: GatewayPrivacy,
        maxTokens: Int
    ) {
        self.taskTier = taskTier
        self.messages = messages
        self.context = context
        self.privacy = privacy
        self.maxTokens = maxTokens
    }
}

public enum GatewayErrorCode: String, Codable, Sendable, CaseIterable {
    case unauthorized
    case rateLimited = "rate_limited"
    case budgetExhausted = "budget_exhausted"
    case upstreamUnavailable = "upstream_unavailable"
    case badRequest = "bad_request"
    case timeout
}

public enum GatewayWireEvent: Sendable, Equatable {
    case meta(route: String, model: String, trainsOnPrompts: Bool)
    case delta(String)
    case done(usage: AIResponse.Usage?)
    case error(code: GatewayErrorCode, retryAfter: Int?)
}

public enum GatewayWireDecodeError: Error, Equatable {
    case empty
    case malformedEvent(String)
    case unknownEvent(String)
    case missingField(String)
    case tokenInURL
    case invalidRequest
}

public enum GatewayWireDecoder {
    public static func rejectTokenInURL(_ raw: String) -> Bool {
        guard let url = URL(string: raw), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return true
        }
        if components.user != nil || components.password != nil {
            return true
        }
        if components.fragment?.isEmpty == false {
            return true
        }
        let query = components.queryItems ?? []
        let banned = ["token", "access_token", "device_token", "authorization", "api_key"]
        return query.contains { item in
            banned.contains(item.name.lowercased())
        }
    }

    public static func decodeRequest(_ data: Data) throws -> GatewayChatRequest {
        let decoder = JSONDecoder()
        guard let request = try? decoder.decode(GatewayChatRequest.self, from: data) else {
            throw GatewayWireDecodeError.invalidRequest
        }
        guard !request.messages.isEmpty, request.maxTokens > 0 else {
            throw GatewayWireDecodeError.invalidRequest
        }
        return request
    }

    public static func decodeSSE(_ text: String) throws -> [GatewayWireEvent] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GatewayWireDecodeError.empty }
        var events: [GatewayWireEvent] = []
        var eventName: String?
        var dataLines: [String] = []

        func flush() throws {
            guard let name = eventName else { return }
            let payload = dataLines.joined(separator: "\n")
            events.append(try decode(name: name, payload: payload))
            eventName = nil
            dataLines = []
        }

        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let row = String(line)
            if row.isEmpty {
                try flush()
                continue
            }
            if row.hasPrefix(":") { continue }
            if row.hasPrefix("event:") {
                eventName = row.dropFirst(6).trimmingCharacters(in: .whitespaces)
            } else if row.hasPrefix("data:") {
                dataLines.append(row.dropFirst(5).trimmingCharacters(in: .whitespaces))
            }
        }
        try flush()
        guard !events.isEmpty else { throw GatewayWireDecodeError.empty }
        return events
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private static func decode(name: String, payload: String) throws -> GatewayWireEvent {
        let data = Data(payload.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let object else { throw GatewayWireDecodeError.malformedEvent(name) }
        switch name {
        case "meta":
            guard let route = object["route"] as? String,
                  let model = object["model"] as? String,
                  let trains = boolValue(object["trainsOnPrompts"]) else {
                throw GatewayWireDecodeError.missingField("meta")
            }
            return .meta(route: route, model: model, trainsOnPrompts: trains)
        case "delta":
            guard let text = object["text"] as? String else {
                throw GatewayWireDecodeError.missingField("delta.text")
            }
            return .delta(text)
        case "done":
            if let usage = object["usage"] as? [String: Any] {
                guard let prompt = intValue(usage["promptTokens"]),
                      let completion = intValue(usage["completionTokens"]) else {
                    throw GatewayWireDecodeError.missingField("done.usage")
                }
                return .done(usage: AIResponse.Usage(promptTokens: prompt, completionTokens: completion))
            }
            return .done(usage: nil)
        case "error":
            guard let raw = object["code"] as? String, let code = GatewayErrorCode(rawValue: raw) else {
                throw GatewayWireDecodeError.missingField("error.code")
            }
            let retry = intValue(object["retryAfter"])
            if code == .rateLimited && retry == nil {
                throw GatewayWireDecodeError.missingField("error.retryAfter")
            }
            return .error(code: code, retryAfter: retry)
        default:
            throw GatewayWireDecodeError.unknownEvent(name)
        }
    }
}
