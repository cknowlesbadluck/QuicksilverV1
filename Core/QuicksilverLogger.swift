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
        category.debug("\(message, privacy: privacy)")
    }

    static func info(_ message: String, category: Logger = general, privacy: OSLogPrivacy = .private) {
        category.info("\(message, privacy: privacy)")
    }

    static func error(_ message: String, category: Logger = general, privacy: OSLogPrivacy = .private) {
        category.error("\(message, privacy: privacy)")
    }
}
