import Foundation
import SwiftUI

/// Device energy state that decorative motion adapts to: Low Power Mode and thermal pressure.
/// Read from public `ProcessInfo` at the app root and passed down the environment, so every
/// TimelineView in the Sanctum and realms slows (or stops) together. Purely presentational:
/// it never feeds the Brain; Nexus remains the sensing path for intelligence.
struct AmbientEnergy: Equatable, Sendable {
    var lowPower = false
    var thermal: ProcessInfo.ThermalState = .nominal

    static let normal = AmbientEnergy()

    static var current: AmbientEnergy {
        AmbientEnergy(
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: ProcessInfo.processInfo.thermalState
        )
    }

    /// True when the device asks apps to save energy.
    var isConserving: Bool { lowPower || thermal == .serious || thermal == .critical }
}

private struct AmbientEnergyKey: EnvironmentKey {
    static let defaultValue = AmbientEnergy.normal
}

extension EnvironmentValues {
    var ambientEnergy: AmbientEnergy {
        get { self[AmbientEnergyKey.self] }
        set { self[AmbientEnergyKey.self] = newValue }
    }
}
