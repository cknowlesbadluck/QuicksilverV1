import Foundation
import os.log

/// Lightweight logging facade.
/// Uses OSLog for privacy-aware, performant logging on device.
/// Avoids print() in production paths.
enum QuicksilverLogger {
    private static let subsystem = "com.quicksilver.app"

    static let general = Logger(subsystem: subsystem, category: "General")
    static let nexus = Logger(subsystem: subsystem, category: "Nexus")
    static let persona = Logger(subsystem: subsystem, category: "Persona")
    static let ui = Logger(subsystem: subsystem, category: "UI")

    static func debug(_ message: String, category: Logger = general, privacy: OSLogPrivacy = .private) {
        if privacy == .public {
            category.debug("\(message, privacy: .public)")
        } else {
            category.debug("\(message, privacy: .private)")
        }
    }

    static func info(_ message: String, category: Logger = general, privacy: OSLogPrivacy = .private) {
        if privacy == .public {
            category.info("\(message, privacy: .public)")
        } else {
            category.info("\(message, privacy: .private)")
        }
    }

    static func error(_ message: String, category: Logger = general, privacy: OSLogPrivacy = .private) {
        if privacy == .public {
            category.error("\(message, privacy: .public)")
        } else {
            category.error("\(message, privacy: .private)")
        }
    }
}
