import Foundation

/// Mercury Gateway wire protocol v1.
///
/// Auth is `Authorization: Bearer <device token>`. A token in the query string,
/// fragment, or userinfo is a protocol violation and must be rejected before any
/// request is sent. The protocol defines no query parameters, so any query string
/// is rejected. Context blocks are kind-tagged. Successful streams are
/// `meta` → zero or more `delta` → `done`. Failures are a single `error`, or
/// `meta` → zero or more `delta` → `error` when the upstream fails after output
/// has begun.
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
    case incompleteStream
    case tokenInURL
    case invalidRequest
}

public enum GatewayWireDecoder {
    /// Returns `true` when the URL must be rejected (userinfo, fragment, or any query).
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
        // Protocol has no query parameters — reject any query string.
        if components.query != nil {
            return true
        }
        return false
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

        // Normalize CRLF / bare CR so splitting on LF works for all common SSE wires.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        for line in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
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
        // Do not flush a trailing unterminated event at EOF (WHATWG discards pending fields).
        guard !events.isEmpty else { throw GatewayWireDecodeError.empty }
        try validateSequence(events)
        return events
    }

    /// Accept only integral JSON numbers representable as `Int` (no truncation / no Double round-trip).
    private static func intValue(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        // Bool bridges to NSNumber — reject it.
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        if CFNumberIsFloatType(number) {
            // Exact integral floats only (e.g. 2.0); 2.9 rejects.
            return Int(exactly: number.doubleValue)
        }
        // Integer NSNumber: parse decimal string to avoid Double precision / Int.max+1 traps.
        return Int(number.stringValue)
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        // JSONSerialization booleans are CFBoolean NSNumbers; reject numeric 0/1.
        guard let number = value as? NSNumber,
              CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else {
            return nil
        }
        return number.boolValue
    }

    private static func jsonObject(_ payload: String, name: String) throws -> [String: Any] {
        let data = Data(payload.utf8)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayWireDecodeError.malformedEvent(name)
        }
        return object
    }

    private static func decodeMeta(_ object: [String: Any]) throws -> GatewayWireEvent {
        guard let route = object["route"] as? String,
              let model = object["model"] as? String,
              let trains = boolValue(object["trainsOnPrompts"]) else {
            throw GatewayWireDecodeError.missingField("meta")
        }
        return .meta(route: route, model: model, trainsOnPrompts: trains)
    }

    private static func decodeDelta(_ object: [String: Any]) throws -> GatewayWireEvent {
        guard let text = object["text"] as? String else {
            throw GatewayWireDecodeError.missingField("delta.text")
        }
        return .delta(text)
    }

    private static func decodeDone(_ object: [String: Any]) throws -> GatewayWireEvent {
        if object.keys.contains("usage") {
            guard let usage = object["usage"] as? [String: Any] else {
                throw GatewayWireDecodeError.missingField("done.usage")
            }
            guard let prompt = intValue(usage["promptTokens"]),
                  let completion = intValue(usage["completionTokens"]) else {
                throw GatewayWireDecodeError.missingField("done.usage")
            }
            return .done(usage: AIResponse.Usage(promptTokens: prompt, completionTokens: completion))
        }
        return .done(usage: nil)
    }

    private static func decodeError(_ object: [String: Any]) throws -> GatewayWireEvent {
        guard let raw = object["code"] as? String, let code = GatewayErrorCode(rawValue: raw) else {
            throw GatewayWireDecodeError.missingField("error.code")
        }
        // retryAfter must be integral when present; fractional JSON is rejected via nil intValue.
        if object["retryAfter"] != nil && intValue(object["retryAfter"]) == nil {
            throw GatewayWireDecodeError.missingField("error.retryAfter")
        }
        let retry = intValue(object["retryAfter"])
        if code == .rateLimited && retry == nil {
            throw GatewayWireDecodeError.missingField("error.retryAfter")
        }
        return .error(code: code, retryAfter: retry)
    }

    private static func decode(name: String, payload: String) throws -> GatewayWireEvent {
        let object = try jsonObject(payload, name: name)
        switch name {
        case "meta":
            return try decodeMeta(object)
        case "delta":
            return try decodeDelta(object)
        case "done":
            return try decodeDone(object)
        case "error":
            return try decodeError(object)
        default:
            throw GatewayWireDecodeError.unknownEvent(name)
        }
    }

    /// Grammar: `meta`→deltas→`done`, lone `error`, or `meta`→deltas→`error`.
    private static func validateSequence(_ events: [GatewayWireEvent]) throws {
        guard let last = events.last else { throw GatewayWireDecodeError.empty }
        switch last {
        case .done, .error:
            break
        case .meta, .delta:
            throw GatewayWireDecodeError.incompleteStream
        }

        if events.count == 1 {
            if case .error = last { return }
            throw GatewayWireDecodeError.incompleteStream
        }

        guard case .meta = events.first else {
            throw GatewayWireDecodeError.malformedEvent("sequence")
        }
        for event in events.dropFirst().dropLast() {
            guard case .delta = event else {
                throw GatewayWireDecodeError.malformedEvent("sequence")
            }
        }
    }
}
