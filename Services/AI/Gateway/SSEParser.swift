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
    /// When a chunk ends on bare CR, the next chunk's leading LF (if any) completes CRLF.
    private var skipLeadingLF = false

    public init() {}

    /// Feed an arbitrary UTF-8 chunk (may contain partial lines).
    public mutating func append(_ chunk: String) throws -> [GatewayWireEvent] {
        carry += chunk
        var events: [GatewayWireEvent] = []
        let scalars = Array(carry.unicodeScalars)
        var index = 0
        if skipLeadingLF {
            if index < scalars.count, scalars[index] == "\n" {
                index += 1
            }
            skipLeadingLF = false
        }
        var lineStart = index
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar != "\r" && scalar != "\n" {
                index += 1
                continue
            }
            let lineScalars = scalars[lineStart..<index]
            var afterTerminator = index + 1
            if scalar == "\r" {
                if afterTerminator < scalars.count, scalars[afterTerminator] == "\n" {
                    afterTerminator += 1
                } else if afterTerminator == scalars.count {
                    // Trailing CR may be the first half of a cross-chunk CRLF.
                    skipLeadingLF = true
                }
            }
            let line = String(String.UnicodeScalarView(lineScalars))
            if let event = try pushLine(line) {
                events.append(event)
            }
            lineStart = afterTerminator
            index = afterTerminator
        }
        carry = String(String.UnicodeScalarView(scalars[lineStart...]))
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
        skipLeadingLF = false
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
