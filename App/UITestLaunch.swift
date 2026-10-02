import Foundation

/// True when XCUITest launched the app with `-uitest`.
/// Decorative Sanctum TimelineViews must freeze so `performAccessibilityAudit`
/// can finish; Reduce Motion alone is off on CI simulators.
enum UITestLaunch {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }
}
