import AppIntents
import QuicksilverIntents

/// M3.5-T9: the app's App Intents package. Including `QuicksilverIntentsPackage`
/// lets Shortcuts/Siri discover the intents compiled into the QuicksilverIntents framework.
struct QuicksilverAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [QuicksilverIntentsPackage.self]
    }
}
