import Foundation
import Observation
import Core

@MainActor
@Observable
public final class NexusCoordinator {
    public private(set) var state = NexusState()

    private let networkMonitor: NetworkMonitoring
    private let batteryMonitor: BatteryMonitoring
    private let storageMonitor: StorageMonitoring
    private let deviceMonitor: DeviceMetricsMonitoring
    private let processor: SignalProcessor
    private let insightEngine: InsightEngine
    private let automationBridge: AutomationBridge
    private let pipeline: SignalPipeline
    private let logger: LoggerService
    private let eventBus: EventBus
    private var currentPersonaID: String = "quicksilver"
    private var isRunning = false
    private var timeContextTask: Task<Void, Never>?
    private var lastPublishedPeriod: EventBus.TimePeriod?
    private var personaSubscriptionID: UUID?

    public init(
        networkMonitor: NetworkMonitoring = NetworkMonitor(),
        batteryMonitor: BatteryMonitoring = BatteryMonitor(),
        storageMonitor: StorageMonitoring = StorageMonitor(),
        deviceMonitor: DeviceMetricsMonitoring = DeviceMetricsMonitor(),
        processor: SignalProcessor = SignalProcessor(),
        insightEngine: InsightEngine = InsightEngine(),
        automationBridge: AutomationBridge = AutomationBridge(),
        logger: LoggerService,
        eventBus: EventBus
    ) {
        self.networkMonitor = networkMonitor
        self.batteryMonitor = batteryMonitor
        self.storageMonitor = storageMonitor
        self.deviceMonitor = deviceMonitor
        self.processor = processor
        self.insightEngine = insightEngine
        self.automationBridge = automationBridge
        self.logger = logger
        self.eventBus = eventBus
        self.pipeline = SignalPipeline(eventBus: eventBus, logger: logger)
    }

    public var isActive: Bool { state.isActive }
    public var bridge: AutomationBridge { automationBridge }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        var newState = state
        newState.isActive = true
        state = newState

        logger.info("Nexus starting", category: logger.nexus)
        automationBridge.configure(nexus: self)

        networkMonitor.onChange = { [weak self] connected, expensive, constrained in
            Task { @MainActor in self?.handleNetwork(connected: connected, expensive: expensive, constrained: constrained) }
        }
        batteryMonitor.onChange = { [weak self] level, description in
            Task { @MainActor in self?.handleBattery(level: level, description: description) }
        }
        storageMonitor.onChange = { [weak self] available, total in
            Task { @MainActor in self?.handleStorage(available: available, total: total) }
        }
        deviceMonitor.onChange = { [weak self] thermal, lowPower in
            Task { @MainActor in self?.handleDevice(thermal: thermal, lowPower: lowPower) }
        }

        networkMonitor.start()
        batteryMonitor.start()
        storageMonitor.start()
        deviceMonitor.start()

        subscribeToPersonaChanges()
        startTimeContextLoop()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        var newState = state
        newState.isActive = false
        state = newState

        timeContextTask?.cancel()
        timeContextTask = nil
        lastPublishedPeriod = nil

        if let personaSubscriptionID {
            let id = personaSubscriptionID
            self.personaSubscriptionID = nil
            Task { await eventBus.unsubscribe(id) }
        }

        networkMonitor.stop()
        batteryMonitor.stop()
        storageMonitor.stop()
        deviceMonitor.stop()
        logger.info("Nexus stopped", category: logger.nexus)
    }

    public func updatePersonaContext(_ personaID: String) {
        currentPersonaID = personaID
    }

    // MARK: - Persona context sync

    /// Keep insight tags aligned with PersonaManager for *all* switch paths
    /// (UI, autonomy, App Intents). Nexus only depends on Core EventBus.
    private func subscribeToPersonaChanges() {
        Task { [weak self] in
            guard let self else { return }
            let id = await self.eventBus.subscribe { [weak self] event in
                guard case .personaDidChange(let personaID) = event else { return }
                Task { @MainActor in
                    self?.updatePersonaContext(personaID)
                }
            }
            await MainActor.run {
                guard let self else { return }
                // stop() may have already run while this subscribe was in flight
                // (it checks personaSubscriptionID synchronously and only unsubscribes
                // if it's already set). If that happened, unsubscribe this one now
                // instead of storing an ID nothing will ever clean up.
                guard self.isRunning else {
                    Task { await self.eventBus.unsubscribe(id) }
                    return
                }
                self.personaSubscriptionID = id
            }
        }
    }

    private func handleNetwork(connected: Bool, expensive: Bool, constrained: Bool) {
        let signal = processor.networkSignal(isConnected: connected, isExpensive: expensive, isConstrained: constrained)
        pipeline.ingest(signal)
        updateLocalState(from: signal, expensive: expensive, constrained: constrained)
    }

    private func handleBattery(level: Double, description: String) {
        let signal = processor.batterySignal(level: level, stateDescription: description)
        pipeline.ingest(signal)
        updateLocalState(from: signal)
    }

    private func handleStorage(available: Double, total: Double) {
        let signal = processor.storageSignal(availableGB: available, totalGB: total)
        pipeline.ingest(signal)
        var newState = state
        newState.availableStorageGB = available
        newState.totalStorageGB = total
        state = newState
        // Must feed updateLocalState so storage signals reach recentSignals,
        // DiagnosticEvents, and InsightEngine (storageInsight was previously dead).
        updateLocalState(from: signal)
    }

    private func handleDevice(thermal: String, lowPower: Bool) {
        var signal = processor.deviceSignal(thermal: thermal, lowPower: lowPower)
        if lowPower {
            signal = Signal(
                id: signal.id, source: signal.source, category: signal.category,
                timestamp: signal.timestamp, value: signal.value,
                numericValue: signal.numericValue, confidence: signal.confidence,
                metadata: signal.metadata.merging(["lowPower": "true", "lowPowerMode": "true"]) { _, new in new }
            )
        }
        pipeline.ingest(signal)
        var newState = state
        newState.thermalState = thermal
        newState.lowPowerMode = lowPower
        state = newState
        // Same path as storage: device/thermal insights require updateLocalState.
        updateLocalState(from: signal)
    }

    private func updateLocalState(from signal: Signal, expensive: Bool = false, constrained: Bool = false) {
        var newState = state
        newState.appendSignal(signal)

        switch signal.source {
        case .network:
            newState.networkStatus = signal.value
            newState.isNetworkExpensive = expensive
            newState.isNetworkConstrained = constrained
            newState.networkHealthScore = signal.value != "disconnected" ? (constrained || expensive ? 70 : 95) : 20
        case .battery:
            if let level = signal.numericValue, level >= 0 {
                newState.batteryLevel = level
                newState.powerHealthScore = Int(level * 100)
            }
            newState.batteryState = signal.value
        default: break
        }

        let scores = [newState.networkHealthScore, newState.powerHealthScore]
        newState.overallHealthScore = scores.reduce(0, +) / max(scores.count, 1)

        let event = DiagnosticEvent(
            signalID: signal.id,
            title: "\(signal.source.rawValue.capitalized) update",
            detail: signal.value,
            severity: .info,
            source: signal.source
        )
        newState.appendEvent(event)

        // personaID is a traceability tag only; InsightEngine generation is persona-agnostic.
        if let insight = insightEngine.insight(for: signal, recent: newState.recentSignals, personaID: currentPersonaID) {
            newState.appendInsight(insight)
            logger.info("Insight: \(insight.title)", category: logger.nexus)
        }

        state = newState
    }

    // MARK: - Time context (persona autonomy)

    /// Publishes time-of-day on start and whenever the period crosses an hour boundary.
    /// Previously only fired once at start, so autonomy never saw morning → afternoon transitions.
    private func startTimeContextLoop() {
        timeContextTask?.cancel()
        timeContextTask = Task { [weak self] in
            await self?.publishCurrentTimeContext(force: true)
            while !Task.isCancelled {
                // Check every 60s; only publish when the period actually changes.
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                await self?.publishCurrentTimeContext(force: false)
            }
        }
    }

    private func publishCurrentTimeContext(force: Bool) async {
        let hour = Calendar.current.component(.hour, from: Date())
        let period: EventBus.TimePeriod
        switch hour {
        case 5..<8: period = .earlyMorning
        case 8..<12: period = .morning
        case 12..<17: period = .afternoon
        case 17..<21: period = .evening
        default: period = .night
        }
        guard force || lastPublishedPeriod != period else { return }
        lastPublishedPeriod = period
        await eventBus.publish(.timeContextDidChange(period: period))
    }
}
