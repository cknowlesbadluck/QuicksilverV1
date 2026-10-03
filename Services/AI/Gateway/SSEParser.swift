import Foundation
import Core

/// Incremental SSE parser aligned with `GatewayWireDecoder` field rules.
///
/// Blank-line-terminated events are decoded via `GatewayWireDecoder.decodeEvent`.
/// Pending fields at EOF are discarded (WHATWG); callers must reject an incomplete stream.
public struct SSEParser: Sendable {
    private var eventName: String?
    private var dataLines: [String] = []
    private var carry = ""

    public init() {}

    /// Feed an arbitrary UTF-8 chunk (may contain partial lines).
    public mutating func append(_ chunk: String) throws -> [GatewayWireEvent] {
        carry += chunk
        var events: [GatewayWireEvent] = []
        // Normalize CRLF / bare CR into LF while scanning.
        while let newline = carry.firstIndex(of: "\n") {
            var line = String(carry[..<newline])
            carry = String(carry[carry.index(after: newline)...])
            if line.hasSuffix("\r") {
                line.removeLast()
            }
            if let event = try pushLine(line) {
                events.append(event)
            }
        }
        // Handle a trailing bare CR without LF (rare); leave it in carry.
        return events
    }

    /// Feed one already-split line (no trailing newline), e.g. from `AsyncBytes.lines`.
    public mutating func pushLine(_ line: String) throws -> GatewayWireEvent? {
        if line.isEmpty {
            return try flush()
        }
        if line.hasPrefix(":") {
            return nil
        }
        if line.hasPrefix("event:") {
            eventName = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            dataLines.append(line.dropFirst(5).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    /// Discard any unterminated pending fields (WHATWG EOF rule).
    public mutating func finish() {
        eventName = nil
        dataLines = []
        carry = ""
    }

    private mutating func flush() throws -> GatewayWireEvent? {
        guard let name = eventName else {
            dataLines = []
            return nil
        }
        let payload = dataLines.joined(separator: "\n")
        eventName = nil
        dataLines = []
        return try GatewayWireDecoder.decodeEvent(name: name, data: payload)
    }
}
