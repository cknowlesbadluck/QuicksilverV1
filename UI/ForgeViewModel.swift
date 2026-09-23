import Foundation
import Observation
import Core
import Personas
import Nexus

/// View model for The Workshop (Forge chamber).
/// All intelligence and chamber decisions come from MercuryBrain.
/// UI only observes aspect + instruments; it never selects engines.
@MainActor
@Observable
final class ForgeViewModel {
    private(set) var activePersonaID: String = "forge"
    private(set) var activeAspect: Aspect = .quicksilver
    private(set) var livingStatus: String = "Workshop is dormant."
    private(set) var latestInsight: Insight?
    private(set) var overallHealthScore: Int = 100
    private(set) var batteryLevelText: String = "—"
    private(set) var networkStatus: String = "—"
    private(set) var thermalState: String = "—"
    private(set) var isAwake: Bool = false
    private(set) var isAwakening: Bool = false


    /// Lightweight session notes captured while in the Workshop (local UI state only).
    private(set) var sessionNotes: [String] = []

    /// Diagnostic instruments derived from Nexus (persona-agnostic).
    private(set) var instruments: [InstrumentReading] = []

    private let container: DependencyContainer
    private var refreshTask: Task<Void, Never>?

    struct InstrumentReading: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
        let severity: Severity

        enum Severity: String {
            case nominal, elevated, critical
        }
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

        // Chamber is awake when Brain has selected the Forge aspect.
        isAwake = activeAspect == .forge

        instruments = buildInstruments(from: state)
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

    /// Enter the Workshop chamber via Brain (never directly via PersonaManager).
    func awakenForge() async {
        isAwakening = true
        defer { isAwakening = false }

        do {
            try await container.brain.switchPersona(to: "forge")
            refresh()
        } catch {
            livingStatus = "Workshop could not awaken: \(error.localizedDescription)"
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
            if container.brain.activeAspect != .forge {
                try await container.brain.switchPersona(to: "forge")
            }
            let answer = try await container.brain.ask(query)
            refresh()
            return answer
        } catch {
            return "Workshop is silent: \(error.localizedDescription)"
        }
    }

    /// Quick instrument action: ask Brain to diagnose the current pressure point.
    func runDiagnosticInstrument() async -> String {
        let query: String
        if overallHealthScore < 40 {
            query = "Diagnose current device health pressure and recommend the smallest safe next step."
        } else if thermalState.lowercased().contains("serious") || thermalState.lowercased().contains("critical") {
            query = "Thermal state is elevated. Diagnose causes and give a precise containment plan."
        } else {
            query = "Run a concise Forge diagnostic of battery, thermal, and network. Report only what matters."
        }
        return await askForge(query)
    }

    // MARK: - Instruments

    private func buildInstruments(from state: NexusState) -> [InstrumentReading] {
        var list: [InstrumentReading] = []

        let batteryPct = state.batteryLevel.map { Int($0 * 100) } ?? -1
        let batterySeverity: InstrumentReading.Severity
        if batteryPct < 0 { batterySeverity = .nominal }
        else if batteryPct < 15 { batterySeverity = .critical }
        else if batteryPct < 30 || state.lowPowerMode { batterySeverity = .elevated }
        else { batterySeverity = .nominal }
        list.append(InstrumentReading(
            id: "battery",
            label: "Power",
            value: batteryPct >= 0 ? "\(batteryPct)%" : "—",
            severity: batterySeverity
        ))

        let thermal = state.thermalState.lowercased()
        let thermalSeverity: InstrumentReading.Severity
        if thermal.contains("critical") { thermalSeverity = .critical }
        else if thermal.contains("serious") || thermal.contains("elevated") { thermalSeverity = .elevated }
        else { thermalSeverity = .nominal }
        list.append(InstrumentReading(
            id: "thermal",
            label: "Thermal",
            value: state.thermalState.capitalized,
            severity: thermalSeverity
        ))

        let healthSeverity: InstrumentReading.Severity
        if state.overallHealthScore < 35 { healthSeverity = .critical }
        else if state.overallHealthScore < 55 { healthSeverity = .elevated }
        else { healthSeverity = .nominal }
        list.append(InstrumentReading(
            id: "health",
            label: "System",
            value: "\(state.overallHealthScore)",
            severity: healthSeverity
        ))

        list.append(InstrumentReading(
            id: "network",
            label: "Link",
            value: state.networkStatus.capitalized,
            severity: .nominal
        ))

        return list
    }
}
