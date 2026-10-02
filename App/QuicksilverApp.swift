import SwiftUI

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()

    @Environment(\.scenePhase) private var scenePhase

    /// UI smoke launches with `-uitest`. Force Reduce Motion so decorative
    /// TimelineViews (AmbientLayer, core fluid/chaos) freeze; otherwise
    /// `performAccessibilityAudit` can hang until XCTest's ~167s timeout.
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    var body: some Scene {
        WindowGroup {
            sanctumRoot
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        container.nexus.start()
                    case .background:
                        container.nexus.stop()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }

    @ViewBuilder
    private var sanctumRoot: some View {
        let root = SanctumView()
            .environment(container)
            .preferredColorScheme(.dark)
        if isUITesting {
            root.environment(\.accessibilityReduceMotion, true)
        } else {
            root
        }
    }
}
