import AppIntents

/// M3.5-T9: exposes this framework's App Intents, entities and App Shortcuts to the
/// App Intents metadata processor. The app target includes it through
/// `QuicksilverAppIntentsPackage` so the system discovers intents that live here.
@available(iOS 17.0, macOS 14.0, *)
public struct QuicksilverIntentsPackage: AppIntentsPackage {}
