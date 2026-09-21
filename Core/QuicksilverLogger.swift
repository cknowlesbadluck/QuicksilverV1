import Foundation
import os.log

/// Lightweight logging facade.
/// Uses OSLog for privacy-aware, performant logging on device.
/// Avoids print() in production paths.
/// Default privacy is `.private`. Prefer LoggerService for injectable paths.
enum QuicksilverLogger {
    private static let subsystem = "com.quicksilver.app"

    static let general = Logger(subsystem: subsystem, category: "General")
    static let nexus = Logger(subsystem: subsystem, category: "Nexus")
    static let persona = Logger(subsystem: subsystem, category: "Persona")
    static let ui = Logger(subsystem: subsystem, category: "UI")

    static func debug(_ message: String, category: Logger = general, isPrivate: Bool = true) {
        if isPrivate {
            category.debug("\(message, privacy: .private)")
        } else {
            category.debug("\(message, privacy: .public)")
        }
    }

    static func info(_ message: String, category: Logger = general, isPrivate: Bool = true) {
        if isPrivate {
            category.info("\(message, privacy: .private)")
        } else {
            category.info("\(message, privacy: .public)")
        }
    }

    static func error(_ message: String, category: Logger = general, isPrivate: Bool = true) {
        if isPrivate {
            category.error("\(message, privacy: .private)")
        } else {
            category.error("\(message, privacy: .public)")
        }
    }
}
