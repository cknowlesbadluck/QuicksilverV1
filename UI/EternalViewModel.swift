import Foundation
import Observation
import Core
import Personas
import Nexus

/// View model for The Eternal Observatory.
/// All intelligence and chamber decisions come from MercuryBrain.
@MainActor
@Observable
final class EternalViewModel {
    private(set) var activePersonaID: String = "eternal"
    private(set) var livingStatus: String = "Eternal is quiescent."
    private(set) var latestInsight: Insight?
    private(set) var overallHealthScore: Int = 100
    private(set) var batteryLevelText: String = "—"
    private(set) var networkStatus: String = "—"
    private(set) var thermalState: String = "—"
    private(set) var isAwake: Bool = false

    /// Lightweight observational notes captured while in Eternal (local UI state only).
    private(set) var observations: [String] = []

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
        isAwake = container.brain.suggestedChamber == .eternal
            || config.id.lowercased() == "eternal"
    }

    func startLiveRefresh(interval: Duration = .seconds(4)) {
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

    /// Switch into Eternal persona via Brain (never directly via PersonaManager).
    func awakenEternal() async {
        do {
            try await container.brain.switchPersona(to: "eternal")
            refresh()
        } catch {
            livingStatus = "Eternal could not awaken: \(error.localizedDescription)"
        }
    }

    /// Capture a long-horizon observation through the Brain memory path.
    func captureObservation(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await container.brain.remember("Eternal observation: \(trimmed)")
        observations.insert(trimmed, at: 0)
        if observations.count > 16 {
            observations = Array(observations.prefix(16))
        }
        refresh()
    }

    /// Ask the Brain a reflective / pattern question while in Eternal context.
    func askEternal(_ query: String) async -> String {
        do {
            if container.brain.activePersonaID.lowercased() != "eternal" {
                try await container.brain.switchPersona(to: "eternal")
            }
            let answer = try await container.brain.ask(query)
            refresh()
            return answer
        } catch {
            return "Eternal is silent: \(error.localizedDescription)"
        }
    }
}
