import SwiftUI

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SanctumView()
                .environment(container)
                .preferredColorScheme(.dark)
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
}
