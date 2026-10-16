import Foundation

/// Which store backs memory this session (M4-T5 disclosure).
public enum MemoryBackend: String, Sendable, Equatable {
    /// SwiftData: the normal, durable store.
    case swiftData
    /// SwiftData couldn't open, so memories are kept in the Keychain-backed backup store.
    case keychainFallback
    /// Injected by tests or previews.
    case injected

    /// Plain-language disclosure for the Memory screen, or nil when nothing needs saying.
    public var disclosure: String? {
        switch self {
        case .keychainFallback:
            return "Using the backup store: the main memory store couldn't open, "
                + "so memories are saved in the Keychain. They stay private and on this device."
        case .swiftData, .injected:
            return nil
        }
    }
}

extension MemoryManager.Failure {
    /// Calm, specific banner text. Never implies data was lost when it wasn't.
    public var userNotice: String {
        switch self {
        case .load:
            return "Couldn't read saved memories. Nothing was deleted; try again later."
        case .save:
            return "The last memory couldn't be saved. Please try again."
        case .delete:
            return "That memory couldn't be removed from storage yet. It's still saved."
        }
    }
}
