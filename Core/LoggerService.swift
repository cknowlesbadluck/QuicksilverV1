import Foundation
import os.log

/// Injectable logging service.
///
/// Marked `@unchecked Sendable` because `os.Logger` is not currently Sendable.
/// All public methods are pure and side-effect free beyond logging; safe to call
/// from any isolation domain.
///
/// Privacy default is `.private`. Callers that intentionally want public messages
/// must pass `isPrivate: false`. Never log raw API keys, tokens, or memory contents.
public final class LoggerService: @unchecked Sendable {
    private let subsystem: String

    public let general: Logger
    public let nexus: Logger
    public let persona: Logger
    public let memory: Logger
    public let ai: Logger
    public let ui: Logger

    public init(subsystem: String = "com.quicksilver.app") {
        self.subsystem = subsystem
        self.general = Logger(subsystem: subsystem, category: "General")
        self.nexus = Logger(subsystem: subsystem, category: "Nexus")
        self.persona = Logger(subsystem: subsystem, category: "Persona")
        self.memory = Logger(subsystem: subsystem, category: "Memory")
        self.ai = Logger(subsystem: subsystem, category: "AI")
        self.ui = Logger(subsystem: subsystem, category: "UI")
    }

    public func debug(_ message: String, category: Logger? = nil, isPrivate: Bool = true) {
        let log = category ?? general
        if isPrivate {
            log.debug("\(message, privacy: .private)")
        } else {
            log.debug("\(message, privacy: .public)")
        }
    }

    public func info(_ message: String, category: Logger? = nil, isPrivate: Bool = true) {
        let log = category ?? general
        if isPrivate {
            log.info("\(message, privacy: .private)")
        } else {
            log.info("\(message, privacy: .public)")
        }
    }

    public func error(_ message: String, category: Logger? = nil, isPrivate: Bool = true) {
        let log = category ?? general
        if isPrivate {
            log.error("\(message, privacy: .private)")
        } else {
            log.error("\(message, privacy: .public)")
        }
    }

    /// Redacts values that look like API keys or long secrets before they can
    /// appear in logs or UI error strings.
    public static func redact(_ value: String?, maxVisible: Int = 4) -> String {
        guard let value, !value.isEmpty else { return "<empty>" }
        let lower = value.lowercased()
        if value.count > 20
            || lower.contains("key")
            || lower.contains("token")
            || lower.contains("secret")
            || value.hasPrefix("xai-")
            || value.hasPrefix("sk-")
            || value.hasPrefix("Bearer ") {
            return "<redacted len=\(value.count)>"
        }
        if value.count <= maxVisible {
            return String(repeating: "*", count: value.count)
        }
        let prefix = value.prefix(maxVisible)
        return "\(prefix)…<redacted>"
    }
}
