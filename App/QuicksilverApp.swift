import SwiftUI
import UIKit

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
                        container.aiService.releaseOnDeviceResources() // M3.5-T4: don't hold a warm session in background
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    container.aiService.releaseOnDeviceResources() // M3.5-T4: memory pressure drops the warm session
                }
        }
    }
}
