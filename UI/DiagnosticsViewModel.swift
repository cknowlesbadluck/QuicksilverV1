import Foundation
import Observation
import Core
import Nexus

@MainActor
@Observable
final class DiagnosticsViewModel {
    private(set) var isActive: Bool = false
    private(set) var overallHealth: Int = 100
    private(set) var insights: [Insight] = []
    private(set) var recentSignals: [Signal] = []
    private(set) var networkStatus: String = "—"
    private(set) var batteryText: String = "—"
    private(set) var thermal: String = "—"
    private(set) var lowPower: Bool = false
    private(set) var lastRefresh: Date = Date()

    private let container: DependencyContainer
    private var refreshTask: Task<Void, Never>?

    init(container: DependencyContainer) {
        self.container = container
        refresh()
    }

    func refresh() {
        let state = container.nexus.state
        isActive = state.isActive
        overallHealth = state.overallHealthScore
        insights = Array(state.recentInsights.prefix(12))
        recentSignals = Array(state.recentSignals.prefix(20))
        networkStatus = state.networkStatus.capitalized
        batteryText = state.batteryLevel.map { "\(Int($0 * 100))% (\(state.batteryState))" } ?? "—"
        thermal = state.thermalState.capitalized
        lowPower = state.lowPowerMode
        lastRefresh = Date()
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

    // deinit must not touch MainActor-isolated state under Swift 6.
    // Callers should invoke stopLiveRefresh() from onDisappear.
}
