import Foundation

public actor IntegrationPlaneClient {
    public enum ClientError: Error, LocalizedError, Sendable {
        case invalidResponse
        case remoteError(String)
        case malformedToolResult

        public var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The integration plane returned an invalid response."
            case .remoteError(let message):
                return message
            case .malformedToolResult:
                return "The integration plane returned a malformed tool result."
            }
        }
    }

    private let endpoint: URL
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var requestID = 0
    private var sessionID: String?

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func initialize() async throws {
        let response = try await call(
            method: "initialize",
            params: [
                "protocolVersion": .string("2025-06-18"),
                "capabilities": .object([:]),
                "clientInfo": .object([
                    "name": .string("Quicksilver"),
                    "version": .string("0.1.0")
                ])
            ]
        )
        guard response["result"] != nil else {
            throw ClientError.remoteError(Self.errorMessage(from: response) ?? "MCP initialization failed.")
        }
    }

    public func listTools() async throws -> [[String: AnyCodable]] {
        let response = try await call(method: "tools/list", params: [:])
        guard let result = response["result"],
              case let .object(object) = result,
              case let .array(tools) = object["tools"] else {
            throw ClientError.malformedToolResult
        }
        return tools.compactMap { value in
            guard case let .object(tool) = value else { return nil }
            return tool
        }
    }

    public func callTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> AnyCodable {
        let response = try await call(
            method: "tools/call",
            params: [
                "name": .string(name),
                "arguments": .object(arguments)
            ]
        )
        if let error = Self.errorMessage(from: response) {
            throw ClientError.remoteError(error)
        }
        guard let result = response["result"] else {
            throw ClientError.malformedToolResult
        }
        return result
    }

    private func call(
        method: String,
        params: [String: AnyCodable]
    ) async throws -> [String: AnyCodable] {
        requestID += 1
        let request = MCPRequest(
            jsonrpc: "2.0",
            id: requestID,
            method: method,
            params: .object(params)
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionID {
            urlRequest.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id")
        }
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ClientError.invalidResponse
        }

        if let returnedSessionID = http.value(forHTTPHeaderField: "Mcp-Session-Id") {
            sessionID = returnedSessionID
        }

        if data.isEmpty { return [:] }

        if let json = try? decoder.decode([String: AnyCodable].self, from: data) {
            return json
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        let lines = text.split(whereSeparator: \.isNewline)
        if let eventData = lines.first(where: { $0.hasPrefix("data:") }) {
            let payload = eventData.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let payloadData = payload.data(using: .utf8),
                  let json = try? decoder.decode([String: AnyCodable].self, from: payloadData) else {
                throw ClientError.invalidResponse
            }
            return json
        }

        throw ClientError.invalidResponse
    }

    private static func errorMessage(from response: [String: AnyCodable]) -> String? {
        guard let error = response["error"], case let .object(object) = error,
              case let .string(message) = object["message"] else { return nil }
        return message
    }
}

private struct MCPRequest: Codable, Sendable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: AnyCodable
}

public enum AnyCodable: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case object([String: AnyCodable])
    case array([AnyCodable])

    public init(_ value: Any) {
        switch value {
        case let value as AnyCodable:
            self = value
        case let value as Bool:
            self = .bool(value)
        case let value as Int:
            self = .int(value)
        case let value as Double:
            self = .double(value)
        case let value as String:
            self = .string(value)
        case let value as [String: AnyCodable]:
            self = .object(value)
        case let value as [AnyCodable]:
            self = .array(value)
        default:
            self = .string(String(describing: value))
        }
    }
}
