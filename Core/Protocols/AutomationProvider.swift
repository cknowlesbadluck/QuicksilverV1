import Foundation

/// Contract for system automation surfaces (App Intents, Shortcuts, etc.).
/// Implementations live in the Intents / Automation layer.
public protocol AutomationProvider: AnyObject {
    /// Configure the provider with the live dependency graph. Called once at launch.
    func configure()

    /// Trigger a named automation. May throw `AppError.unsupportedFeature`.
    func trigger(named name: String) throws
}
