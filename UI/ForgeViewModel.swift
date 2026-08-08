import Foundation
import Observation
import Core
import Personas
import Nexus

/// View model for The Forge realm.
/// All intelligence and chamber decisions come from MercuryBrain.
@MainActor
@Observable
final class ForgeViewModel {
    private(set) var activePersonaID: String = "forge"
    private(set) var livingStatus: String = "Forge is dormant."
    private(set) var latestInsight: Insight?
    private(set) var overallHealthScore: Int = 100
    private(set) var batteryLevelText: String = "—"
    private(set) var networkStatus: String = "—"
    private(set) var thermalState: String = "—"
    private(set) var isAwake: Bool = false

    /// Lightweight session notes captured while in the Forge (local UI state only).
    private(set) var sessionNotes: [String] = []

    private let container: DependencyContainer
    private var refreshTask: Task<Void, Never>?

    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }

    func refresh() {
        let config = container.activeConfiguration
        activePersonaID = config.id

        container.brain.refreshLivingStatus()
        livingStatus = container.brain.livingStatus

        let state = container.nexus.state
        latestInsight = state.recentInsights.first
        overallHealthScore = state.overallHealthScore
        batteryLevelText = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "—"
        networkStatus = state.networkStatus.capitalized
        thermalState = state.thermalState.capitalized

        // Brain owns chamber suggestion; UI only observes.
        isAwake = container.brain.suggestedChamber == .forge
            || config.id.lowercased() == "forge"
    }

    func startLiveRefresh(interval: Duration = .seconds(3)) {
        stopLiveRefresh()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { break }
                self?.refresh()
            }
        }
    }

    func stopLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Switch into Forge persona via Brain (never directly via PersonaManager).
    func awakenForge() async {
        do {
            try await container.brain.switchPersona(to: "forge")
            refresh()
        } catch {
            // Surface via living status; Brain logs internally.
            livingStatus = "Forge could not awaken: \(error.localizedDescription)"
        }
    }

    /// Capture a short constructive note through the Brain memory path.
    func captureNote(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await container.brain.remember("Forge note: \(trimmed)")
        sessionNotes.insert(trimmed, at: 0)
        if sessionNotes.count > 12 {
            sessionNotes = Array(sessionNotes.prefix(12))
        }
        refresh()
    }

    /// Ask the Brain a construction-oriented question while in Forge context.
    func askForge(_ query: String) async -> String {
        do {
            // Ensure Forge persona is active so chamber + bias apply.
            if container.brain.activePersonaID.lowercased() != "forge" {
                try await container.brain.switchPersona(to: "forge")
            }
            let answer = try await container.brain.ask(query)
            refresh()
            return answer
        } catch {
            return "Forge is silent: \(error.localizedDescription)"
        }
    }
}
