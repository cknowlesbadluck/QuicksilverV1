import Foundation
import Core

/// Thermal and Low Power Mode monitor using ProcessInfo (public API only).
/// `@MainActor` with an isolated conformance (issue #252), replacing `@unchecked Sendable`.
/// Observes via main-actor tasks over `NotificationCenter.notifications(named:)`; tasks are
/// Sendable, so the nonisolated deinit can cancel them (no observer tokens to leak).
@MainActor
public final class DeviceMetricsMonitor: @MainActor DeviceMetricsMonitoring {
    public var diagnosticID: String { "device" }

    private var observers: [Task<Void, Never>] = []

    public private(set) var thermalStateDescription: String = "unknown"
    public private(set) var isLowPowerMode = false
    public var onChange: ((String, Bool) -> Void)?

    public init() {}

    public func start() {
        guard observers.isEmpty else { return }
        update()
        observers = [
            ProcessInfo.thermalStateDidChangeNotification,
            .NSProcessInfoPowerStateDidChange
        ].map { name in
            Task { @MainActor [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    self?.update()
                }
            }
        }
    }

    public func stop() {
        observers.forEach { $0.cancel() }
        observers = []
    }

    deinit {
        observers.forEach { $0.cancel() }
    }

    private func update() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalStateDescription = "nominal"
        case .fair: thermalStateDescription = "fair"
        case .serious: thermalStateDescription = "serious"
        case .critical: thermalStateDescription = "critical"
        @unknown default: thermalStateDescription = "unknown"
        }
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        onChange?(thermalStateDescription, isLowPowerMode)
    }
}
