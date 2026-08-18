import Foundation
import Observation
import Core
import Personas
import Nexus

@MainActor
@Observable
final class SanctumViewModel {
    private(set) var activePersonaID: String = "quicksilver"
    private(set) var livingStatus: String = "Quicksilver is present."
    private(set) var latestInsight: Insight?
    private(set) var batteryLevelText: String = "—"
    private(set) var networkStatus: String = "—"
    private(set) var thermalState: String = "—"
    private(set) var overallHealthScore: Int = 100
    private(set) var visualState: VisualState = .idle

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
        batteryLevelText = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "—"
        networkStatus = state.networkStatus.capitalized
        thermalState = state.thermalState.capitalized
        overallHealthScore = state.overallHealthScore

        // Invisible Architecture: visual state owned by Brain.
        visualState = container.brain.visualState
    }

    func startLiveRefresh(interval: Duration = .seconds(2)) {
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
}
