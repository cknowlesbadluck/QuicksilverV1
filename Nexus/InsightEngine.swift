import Foundation

/// Produces insights from signals. Persona-agnostic — voice is applied at presentation time.
/// `personaStyle` on Insight is an optional tag only; generation never varies by persona.
public struct InsightEngine: Sendable {
    public init() {}

    /// - Parameter personaID: Optional tag stored on the Insight for traceability.
    ///   Does not influence title, body, severity, or action. Presentation applies voice.
    public func insight(for signal: Signal, recent: [Signal], personaID: String = "") -> Insight? {
        switch signal.source {
        case .network: return networkInsight(signal: signal, recent: recent, personaID: personaID)
        case .battery: return batteryInsight(signal: signal, recent: recent, personaID: personaID)
        case .storage: return storageInsight(signal: signal, personaID: personaID)
        case .device: return deviceInsight(signal: signal, personaID: personaID)
        default: return nil
        }
    }

    // MARK: - Sources

    private func networkInsight(signal: Signal, recent: [Signal], personaID: String) -> Insight? {
        let recentNetwork = recent.filter {
            $0.source == .network && $0.timestamp > Date().addingTimeInterval(-600)
        }

        if signal.value == "disconnected" {
            return make(
                InsightContent(
                    title: "Network lost",
                    body: "The device is currently offline.",
                    severity: .warning,
                    action: "Check Wi-Fi or cellular settings."
                ),
                signal: signal,
                personaID: personaID
            )
        }

        if recentNetwork.count >= 3 {
            return make(
                InsightContent(
                    title: "Network instability",
                    body: "Connection state changed \(recentNetwork.count) times in the last 10 minutes.",
                    severity: .notice,
                    action: "Consider moving closer to the access point or toggling Airplane Mode."
                ),
                signal: signal,
                personaID: personaID
            )
        }

        if signal.value == "constrained" || signal.value == "expensive" {
            return make(
                InsightContent(
                    title: "Constrained network",
                    body: "The current path is marked \(signal.value). Background data may be limited.",
                    severity: .notice,
                    action: nil
                ),
                signal: signal,
                personaID: personaID
            )
        }

        return nil
    }

    private func batteryInsight(signal: Signal, recent: [Signal], personaID: String) -> Insight? {
        // UIDevice.batteryLevel is -1 when monitoring is unavailable (simulator, first tick).
        guard let level = signal.numericValue, level >= 0 else { return nil }

        if level < 0.15 && signal.value != "charging" {
            return make(
                InsightContent(
                    title: "Low battery",
                    body: "Battery is at \(Int(level * 100))%.",
                    severity: .warning,
                    action: "Connect to power or enable Low Power Mode."
                ),
                signal: signal,
                personaID: personaID
            )
        }

        let previous = recent.first { $0.source == .battery && $0.id != signal.id }
        if let prevLevel = previous?.numericValue, prevLevel >= 0, prevLevel - level > 0.08 {
            return make(
                InsightContent(
                    title: "Elevated drain",
                    body: "Battery dropped faster than usual in the recent window.",
                    severity: .notice,
                    action: "Review recently used apps or background activity."
                ),
                signal: signal,
                personaID: personaID
            )
        }

        return nil
    }

    private func storageInsight(signal: Signal, personaID: String) -> Insight? {
        guard let available = signal.numericValue, available < 5.0 else { return nil }

        return make(
            InsightContent(
                title: "Storage pressure",
                body: String(format: "Only %.1f GB free.", available),
                severity: available < 2.0 ? .warning : .notice,
                action: "Offload unused apps or clear large downloads."
            ),
            signal: signal,
            personaID: personaID
            )
    }

    private func deviceInsight(signal: Signal, personaID: String) -> Insight? {
        if signal.value.contains("serious") || signal.value.contains("critical") {
            return make(
                InsightContent(
                    title: "Thermal pressure",
                    body: "Device is under elevated thermal load (\(signal.value)).",
                    severity: .warning,
                    action: "Reduce workload or move to a cooler environment."
                ),
                signal: signal,
                personaID: personaID
            )
        }
        return nil
    }

    // MARK: - Factory

    private struct InsightContent {
        let title: String
        let body: String
        let severity: DiagnosticEvent.Severity
        let action: String?
    }

    private func make(_ content: InsightContent, signal: Signal, personaID: String) -> Insight {
        Insight(
            title: content.title,
            body: content.body,
            severity: content.severity,
            relatedSignalIDs: [signal.id],
            personaStyle: personaID,
            suggestedAction: content.action
        )
    }
}
