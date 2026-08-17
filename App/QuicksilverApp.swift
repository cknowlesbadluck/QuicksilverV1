import SwiftUI
import Sentry

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()

    init() {
        SentrySDK.start { options in
            options.dsn = "https://b2513ae812ea7432f18af51a5bbf30a7@o4511884245794816.ingest.us.sentry.io/4511884267225088"

            // Environment & release
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif

            // Prefer lower sample rates in production to control cost / volume
            options.tracesSampleRate = 0.2
            options.configureProfiling = { profiling in
                profiling.lifecycle = .trace
                profiling.sessionSampleRate = 0.1
            }

            // Useful diagnostics without being overly aggressive
            options.enableMetrics = true
            options.enableCaptureFailedRequests = true
            options.attachScreenshot = false          // privacy-conscious default
            options.enableAppHangTracking = true

            // Release name helps group events (matches MARKETING_VERSION when possible)
            options.releaseName = "Quicksilver@0.2.0"
        }
    }

    var body: some Scene {
        WindowGroup {
            SanctumView()
                .environment(container)
                .preferredColorScheme(.dark)
        }
    }
}
