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
    private var requestID: Int = 0
    private var sessionID: String?

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    public func initialize() async throws {
        let result = try await call(method: "initialize", params: [
            "protocolVersion": "2025-06-18",
            "capabilities": [:],
            "clientInfo": [
                "name": "Quicksilver",
                "version": "0.1.0"
            ]
        ])
        guard result["result"] != nil else {
            throw ClientError.remoteError(Self.errorMessage(from: result) ?? "MCP initialization failed.")
        }
    }

    public func listTools() async throws -> [[String: AnyCodable]] {
        let response = try await call(method: "tools/list", params: [:])
        guard let result = response["result"],
              let tools = result.objectValue?["tools"]?.arrayValue else {
            throw ClientError.malformedToolResult
        }
        return tools
    }

    public func callTool(name: String, arguments: [String: AnyCodable] = [:]) async throws -> AnyCodable {
        let response = try await call(
            method: "tools/call",
            params: [
                "name": name,
                "arguments": AnyCodable(arguments)
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

    private func call(method: String, params: [String: Any]) async throws -> [String: AnyCodable] {
        requestID += 1
        let request = MCPRequest(
            jsonrpc: "2.0",
            id: requestID,
            method: method,
            params: AnyCodable(params)
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

        if data.isEmpty {
            return [:]
        }

        if let json = try? decoder.decode([String: AnyCodable].self, from: data) {
            return json
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        if let eventData = text.split(separator: "\n").first(where: { $0.hasPrefix("data:") }) {
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
        response["error"]?.objectValue?["message"]?.stringValue
    }
}

private struct MCPRequest: Codable, Sendable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: AnyCodable
}

public struct AnyCodable: Codable, Sendable, Hashable {
    public let value: AnyHashable

    public init(_ value: Any) {
        if let value = value as? AnyHashable {
            self.value = value
        } else {
            self.value = String(describing: value)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let value = try? container.decode(Bool.self) {
            self.value = value
        } else if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode([String: AnyCodable].self) {
            self.value = value as NSDictionary
        } else if let value = try? container.decode([AnyCodable].self) {
            self.value = value as NSArray
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let value as Bool:
            try container.encode(value)
        case let value as Int:
            try container.encode(value)
        case let value as Double:
            try container.encode(value)
        case let value as String:
            try container.encode(value)
        case let value as [String: AnyCodable]:
            try container.encode(value)
        case let value as [AnyCodable]:
            try container.encode(value)
        case _ as NSNull:
            try container.encodeNil()
        default:
            try container.encode(String(describing: value))
        }
    }

    public var objectValue: [String: AnyCodable]? { value as? [String: AnyCodable] }
    public var arrayValue: [[String: AnyCodable]]? { value as? [[String: AnyCodable]] }
    public var stringValue: String? { value as? String }
}
