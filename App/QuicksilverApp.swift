import SwiftUI
import Sentry

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()

    init() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !ProcessInfo.processInfo.arguments.contains("-uitest"),
              let dsn = Bundle.main.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty else { return }

        SentrySDK.start { options in
            options.dsn = dsn

            // Environment & release
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif

            // Only errors and hangs; never capture network payloads or performance data.
            options.enableMetrics = false
            options.enableCaptureFailedRequests = false
            options.sendDefaultPii = false
            options.attachScreenshot = false
            options.enableAppHangTracking = true

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                options.releaseName = "Quicksilver@\(version)"
            }
            options.dist = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        }
    }

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
