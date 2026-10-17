import AppIntents
import Foundation
import Core

/// "Forget this": deletes one saved note from Shortcuts/Siri. Notes only (the entity and the
/// Brain both refuse chat turns and system items), on device, through `IntelligenceSurface`.
/// Destructive, so the user must confirm, and the device must be unlocked.
@available(iOS 17.0, macOS 14.0, *)
public struct ForgetNoteIntent: AppIntent {
    public static let title: LocalizedStringResource = "Forget a Note"
    public static let description = IntentDescription(
        "Delete one note you asked Quicksilver to remember. Asks before deleting; can't be undone."
    )
    public static let openAppWhenRun: Bool = false
    public static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Note")
    public var note: MemoryEntity

    public init() {}
    public init(note: MemoryEntity) {
        self.note = note
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let surface = try IntentDependencies.shared.requireSurface()
        try await requestConfirmation(result: .result(dialog: IntentDialog(stringLiteral: Self.confirmation(for: note))))
        let message = await Self.forget(note, using: surface)
        return .result(dialog: IntentDialog(stringLiteral: message))
    }

    /// Asked before anything is deleted. Names the note by its first line only.
    static func confirmation(for note: MemoryEntity) -> String {
        "Forget \"\(MemoryEntity.title(for: note.text))\"? This can't be undone."
    }

    /// The deletion itself, after the user confirmed.
    @MainActor
    static func forget(_ note: MemoryEntity, using surface: IntelligenceSurface) async -> String {
        await surface.forgetNote(id: note.id)
            ? "Forgotten."
            : "That note is already gone, or it isn't a saved note."
    }
}
