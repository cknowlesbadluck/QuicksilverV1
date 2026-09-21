import Foundation
import Observation
import Core
import Personas
import Nexus
import Memory

/// View model for The Observatory (Eternal chamber).
/// All intelligence and chamber decisions come from MercuryBrain.
/// UI only observes aspect + continuity instruments.
@MainActor
@Observable
final class EternalViewModel {
    private(set) var activePersonaID: String = "eternal"
    private(set) var activeAspect: Aspect = .quicksilver
    private(set) var livingStatus: String = "Observatory is quiescent."
    private(set) var latestInsight: Insight?
    private(set) var overallHealthScore: Int = 100
    private(set) var batteryLevelText: String = "—"
    private(set) var networkStatus: String = "—"
    private(set) var thermalState: String = "—"
    private(set) var isAwake: Bool = false

    /// Lightweight observational notes captured while in Eternal (local UI state only).
    private(set) var observations: [String] = []

    /// Continuity constellation — high-importance memory items (persona-scoped).
    private(set) var constellation: [ConstellationNode] = []

    private let container: DependencyContainer
    private var refreshTask: Task<Void, Never>?

    struct ConstellationNode: Identifiable, Equatable {
        let id: String
        let summary: String
        let category: String
        let importance: Double
    }

    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }

    func refresh() {
        let config = container.activeConfiguration
        activePersonaID = config.id
        activeAspect = container.brain.activeAspect

        container.brain.refreshLivingStatus()
        livingStatus = container.brain.livingStatus

        let state = container.nexus.state
        latestInsight = state.recentInsights.first
        overallHealthScore = state.overallHealthScore
        batteryLevelText = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "—"
        networkStatus = state.networkStatus.capitalized
        thermalState = state.thermalState.capitalized

        isAwake = activeAspect == .eternal

        constellation = buildConstellation(personaID: config.id)
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

    /// Enter the Observatory chamber via Brain.
    func awakenEternal() async {
        do {
            try await container.brain.switchPersona(to: "eternal")
            refresh()
        } catch {
            livingStatus = "Observatory could not awaken: \(error.localizedDescription)"
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
            if container.brain.activeAspect != .eternal {
                try await container.brain.switchPersona(to: "eternal")
            }
            let answer = try await container.brain.ask(query)
            refresh()
            return answer
        } catch {
            return "Observatory is silent: \(error.localizedDescription)"
        }
    }

    /// Continuity instrument: ask Brain to surface patterns across recent memory.
    func runContinuityInstrument() async -> String {
        let query = "From recent memory and device signals, surface the most important continuity patterns. Be precise and minimal."
        return await askEternal(query)
    }

    // MARK: - Constellation

    private func buildConstellation(personaID: String) -> [ConstellationNode] {
        let policy = container.personaManager.activeMemoryPolicy
        let query = MemoryQuery(
            personaScope: personaID,
            minimumImportance: max(policy.retentionThreshold, 0.35),
            limit: 8
        )
        let items = container.memoryManager.items(matching: query)
        return items.map { item in
            ConstellationNode(
                id: item.id.uuidString,
                summary: String(item.value.prefix(120)),
                category: item.category.rawValue,
                importance: item.importance
            )
        }
    }
}
