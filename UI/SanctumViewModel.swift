import Foundation
import Observation
import Core
import Personas
import Nexus

@MainActor
@Observable
final class SanctumViewModel {
    private(set) var activePersonaID: String = "quicksilver"
    private(set) var activeAspect: Aspect = .quicksilver
    private(set) var livingStatus: String = LivingNarration.defaultStatus
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
        activeAspect = container.brain.activeAspect

        let state = container.nexus.state
        latestInsight = state.recentInsights.first
        batteryLevelText = state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "—"
        networkStatus = state.networkStatus.capitalized
        thermalState = state.thermalState.capitalized
        overallHealthScore = state.overallHealthScore

        // Invisible Architecture: visual state and aspect owned by Brain.
        visualState = container.brain.visualState
    }

    /// Event-driven live refresh. Replaces the previous 2 s polling loop.
    /// Subscribes to EventBus and refreshes only when a relevant signal arrives.
    ///
    /// The stream is filtered to Sanctum-relevant events before buffering and
    /// coalesced to a single pending trigger (`refresh()` reads full current
    /// state, so one pending trigger is equivalent to many). After the stream is
    /// registered, one refresh runs immediately so any change published between
    /// the call and registration is still reflected.
    func startLiveRefresh(interval: Duration = .seconds(2)) {
        // `interval` retained for API compatibility; ignored.
        _ = interval
        stopLiveRefresh()
        let eventBus = container.eventBus
        refreshTask = Task { [weak self] in
            let stream = await eventBus.events(bufferingNewest: 1) { event in
                SanctumViewModel.isRelevant(event)
            }
            // Stream is now registered; catch up on anything published before that.
            guard !Task.isCancelled else { return }
            self?.refresh()
            for await _ in stream {
                guard !Task.isCancelled, let self else { break }
                self.refresh()
            }
        }
    }

    func stopLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    /// Accent source for the living place — prefer aspect over legacy persona ID.
    var presenceAccentID: String {
        activeAspect.rawValue
    }

    /// Events that affect displayed Sanctum state.
    /// `nonisolated` so the EventBus actor can evaluate it as a stream filter.
    nonisolated private static func isRelevant(_ event: EventBus.Event) -> Bool {
        switch event {
        case .personaDidChange,
             .memoryDidUpdate,
             .signalReceived,
             .timeContextDidChange,
             .batteryPressureChanged,
             .thermalPressureChanged,
             .networkConditionChanged,
             .aiRequestCompleted,
             .focusDidChange:
            return true
        case .featureFlagDidChange, .aiRequestStarted, .custom:
            return false
        }
    }
}
