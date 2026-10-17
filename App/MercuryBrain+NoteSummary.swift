import Foundation
import Core
import ServicesAI

extension MercuryBrain {
    /// One-line on-device summary of a saved note (notes only; chat turns return nil).
    /// nil when the note is missing, too short to need a summary, or the on-device model
    /// is unavailable. Never routes to the cloud.
    func noteSummary(id: UUID, using summarizer: (any NoteSummarizing)? = nil) async -> String? {
        guard let note = memoryNote(id: id) else { return nil }
        return await (summarizer ?? aiService.noteSummarizer).summary(of: note.value)
    }
}
