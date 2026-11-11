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
    /// Redacted CHR-55 evidence text for this run. Read-only; never an acceptance claim.
    private(set) var deviceRunSummary: String = ""

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
        deviceRunSummary = Self.deviceRunSummary(
            onDeviceModel: container.aiService.onDeviceAvailability,
            now: lastRefresh
        )
    }

    /// Fresh stamp for the running process. Nothing is persisted and every check stays `notRun`:
    /// the owner runs the checklist and records CHR-55 in Linear.
    static func deviceRunSummary(
        onDeviceModel: OnDeviceModelAvailability,
        configuration: AppConfiguration = .shared,
        now: Date = Date()
    ) -> String {
        DeviceRunStamp.current(onDeviceModel: onDeviceModel, configuration: configuration, now: now)
            .redactedSummary(now: now)
    }

    /// Event-driven live refresh (replaces the previous polling loop).
    /// Refreshes once after the EventBus stream is registered, then only on relevant events.
    /// Nexus insights are not carried by any EventBus event (and deduped signals skip
    /// publishing), so a slow fallback timer keeps insights and signals fresh.
    func startLiveRefresh(interval: Duration = .seconds(4)) {
        // `interval` retained for API compatibility; ignored.
        _ = interval
        stopLiveRefresh()
        refreshTask = EventDrivenRefresh.start(
            eventBus: container.eventBus,
            fallbackInterval: .seconds(60),
            where: { event in DiagnosticsViewModel.isRelevant(event) },
            refresh: { [weak self] in self?.refresh() }
        )
    }

    func stopLiveRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // deinit must not touch MainActor-isolated state under Swift 6.
    // Callers should invoke stopLiveRefresh() from onDisappear.

    /// Events that affect this chamber's displayed state.
    /// `nonisolated` so the EventBus actor can evaluate it as a stream filter.
    nonisolated private static func isRelevant(_ event: EventBus.Event) -> Bool {
        switch event {
        case .signalReceived,
             .batteryPressureChanged,
             .thermalPressureChanged,
             .networkConditionChanged:
            return true
        case .personaDidChange,
             .memoryDidUpdate,
             .featureFlagDidChange,
             .aiRequestStarted,
             .aiRequestCompleted,
             .focusDidChange,
             .timeContextDidChange,
             .custom:
            return false
        }
    }
}
