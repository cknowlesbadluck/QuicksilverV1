import AppIntents
import Foundation
import Core

/// "Find in my notes" (M3.5-T11 follow-up): searches the user's saved notes on device and
/// returns them to Shortcuts/Siri. Notes only, never chat turns or system items, read through
/// `IntelligenceSurface` (the Brain). No model call and no network: a plain on-device match.
/// Notes are personal, so the device must be unlocked to run it.
@available(iOS 17.0, macOS 14.0, *)
public struct FindNotesIntent: AppIntent {
    public static let title: LocalizedStringResource = "Find in My Notes"
    public static let description = IntentDescription(
        "Search the notes you asked Quicksilver to remember. Runs on device; chat history is never included."
    )
    public static let openAppWhenRun: Bool = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
    /// Results are capped so a broad search can't dump the whole memory into a shortcut.
    public static let maxResults = 10

    @Parameter(title: "Search for")
    public var query: String

    public init() {}
    public init(query: String) {
        self.query = query
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[MemoryEntity]> & ProvidesDialog {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw $query.needsValueError("What should Quicksilver look for in your notes?")
        }
        let surface = try IntentDependencies.shared.requireSurface()
        let notes = surface.memoryNotes(matching: String(trimmed.prefix(200)), limit: Self.maxResults)
            .map(MemoryEntity.init)
        return .result(value: notes, dialog: IntentDialog(stringLiteral: Self.summary(for: notes)))
    }

    /// Spoken/shown summary. Reads at most the first note's title aloud.
    static func summary(for notes: [MemoryEntity]) -> String {
        switch notes.count {
        case 0: return "No saved notes match."
        case 1: return "One note: \(MemoryEntity.title(for: notes[0].text))"
        default: return "\(notes.count) notes match. The first: \(MemoryEntity.title(for: notes[0].text))"
        }
    }
}
