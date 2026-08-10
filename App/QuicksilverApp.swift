import SwiftUI
import Sentry

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()

    init() {
        // Initialize Sentry for crash reporting and error tracking
        SentrySDK.start { options in
            options.dsn = "https://b2513ae812ea7432f18af51a5bbf30a7@o4511884245794816.ingest.us.sentry.io/4511884267225088"
            options.tracesSampleRate = 1.0
            options.profilesSampleRate = 1.0
            options.environment = "production"
            options.enableMetrics = true
            options.enableCaptureFailedRequests = true
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
