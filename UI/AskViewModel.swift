import Foundation
import Observation
import Core
import Memory
import Personas
import ServicesAI
import Nexus

struct ChatTurn: Identifiable, Equatable {
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date

    enum Role: String {
        case user, assistant
    }
}

@MainActor
@Observable
final class AskViewModel {
    var draft: String = ""
    private(set) var isProcessing = false
    private(set) var turns: [ChatTurn] = []
    private(set) var errorMessage: String?
    private(set) var providerName: String = ""

    private let container: DependencyContainer
    private let historyLimit = 40

    init(container: DependencyContainer) {
        self.container = container
        providerName = container.aiService.currentProviderName
    }

    func loadHistory() async {
        await container.memoryManager.load()
        let personaID = container.personaManager.activePersonaID
        let query = MemoryQuery(
            category: .conversation,
            personaScope: personaID,
            keyPrefix: "chat.",
            limit: historyLimit
        )
        let items = container.memoryManager.items(matching: query)
            .sorted { $0.createdAt < $1.createdAt }

        turns = items.compactMap { item in
            let role: ChatTurn.Role = item.metadata["role"] == "assistant" ? .assistant : .user
            return ChatTurn(id: item.id, role: role, text: item.value, createdAt: item.createdAt)
        }
    }

    func submit() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        isProcessing = true
        errorMessage = nil
        providerName = container.aiService.currentProviderName

        let config = container.activeConfiguration
        let policy = container.personaManager.activeMemoryPolicy
        let personaID = config.id

        await appendUserTurn(text: text, personaID: personaID, writeHint: policy.writeImportanceHint)

        do {
            try await fetchAndAppendAssistantResponse(for: text, personaID: personaID, writeHint: policy.writeImportanceHint)
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    private func appendUserTurn(text: String, personaID: String, writeHint: Double?) async {
        let userTurn = ChatTurn(id: UUID(), role: .user, text: text, createdAt: Date())
        turns.append(userTurn)
        draft = ""
        await persistTurn(userTurn, personaID: personaID, writeHint: writeHint)
    }

    private func fetchAndAppendAssistantResponse(for text: String, personaID: String, writeHint: Double?) async throws {
        // All conversation now routes through Mercury Brain
        let responseText = try await container.brain.ask(text)

        let assistantTurn = ChatTurn(
            id: UUID(),
            role: .assistant,
            text: responseText,
            createdAt: Date()
        )
        turns.append(assistantTurn)
        await persistTurn(assistantTurn, personaID: personaID, writeHint: writeHint)
    }

    private func persistTurn(_ turn: ChatTurn, personaID: String, writeHint: Double?) async {
        let key = "chat.\(turn.createdAt.timeIntervalSince1970).\(turn.id.uuidString.prefix(8))"
        await container.memoryManager.set(
            key: key,
            value: turn.text,
            category: .conversation,
            metadata: [
                "role": turn.role.rawValue,
                "persona": personaID
            ],
            importanceBoost: turn.role == .assistant ? writeHint : 0.45,
            personaScope: personaID
        )
    }
}
