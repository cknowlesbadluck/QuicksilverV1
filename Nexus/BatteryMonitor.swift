import Foundation
import Core
#if canImport(UIKit)
import UIKit
#endif

/// Battery perception using only public UIDevice APIs.
/// `@MainActor` with an isolated conformance (issue #252), replacing `@unchecked Sendable`.
/// Observes via main-actor tasks over `NotificationCenter.notifications(named:)`; tasks are
/// Sendable, so the nonisolated deinit can cancel them.
@MainActor
public final class BatteryMonitor: @MainActor BatteryMonitoring {
    public var diagnosticID: String { "battery" }

    private var isRunning = false
    private var observers: [Task<Void, Never>] = []

    public private(set) var level: Double = -1
    public private(set) var stateDescription: String = "unknown"
    public var onChange: ((Double, String) -> Void)?

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        observers = [
            UIDevice.batteryLevelDidChangeNotification,
            UIDevice.batteryStateDidChangeNotification
        ].map { name in
            Task { @MainActor [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    self?.update()
                }
            }
        }
        update()
        #endif
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        observers.forEach { $0.cancel() }
        observers = []
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = false
        #endif
    }

    deinit {
        observers.forEach { $0.cancel() }
    }

    #if canImport(UIKit)
    private func update() {
        let device = UIDevice.current
        level = Double(device.batteryLevel)
        switch device.batteryState {
        case .charging: stateDescription = "charging"
        case .full: stateDescription = "full"
        case .unplugged: stateDescription = "unplugged"
        case .unknown: stateDescription = "unknown"
        @unknown default: stateDescription = "unknown"
        }
        onChange?(level, stateDescription)
    }
    #endif
}
