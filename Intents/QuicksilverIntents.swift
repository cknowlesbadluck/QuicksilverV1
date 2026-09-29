import AppIntents
import Foundation
import Core
import Personas

// MARK: - Get Current Aspect (primary read surface)

@available(iOS 17.0, macOS 14.0, *)
public struct GetCurrentAspectIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Current Aspect"
    public static let description = IntentDescription(
        "Returns the aspect currently chosen by Quicksilver."
    )
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let report = try IntentDependencies.shared.requireSurface().statusReport()
        let aspect = report.split(separator: "|")
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? report
        return .result(value: aspect)
    }
}

// MARK: - Capture Memory

@available(iOS 17.0, macOS 14.0, *)
public struct CaptureMemoryIntent: AppIntent {
    public static let title: LocalizedStringResource = "Remember This"
    public static let description = IntentDescription("Capture a short note or thought into Quicksilver Memory.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Content")
    public var content: String

    public init() {}
    public init(content: String) {
        self.content = content
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let surface = try IntentDependencies.shared.requireSurface()
        let truncated = String(content.prefix(500))
        await surface.remember(truncated)
        return .result(value: "Captured: \(truncated)")
    }
}

// MARK: - Get Context

@available(iOS 17.0, macOS 14.0, *)
public struct GetContextIntent: AppIntent {
    public static let title: LocalizedStringResource = "What's the Context"
    public static let description = IntentDescription(
        "Returns a short summary of current Quicksilver state (aspect + health signals)."
    )
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let report = try IntentDependencies.shared.requireSurface().statusReport()
        return .result(value: report)
    }
}

// MARK: - Report Status

@available(iOS 17.0, macOS 14.0, *)
public struct ReportStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Report Quicksilver Status"
    public static let description = IntentDescription("Full diagnostic report from Nexus (network, battery, health).")
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let report = try IntentDependencies.shared.requireSurface().statusReport()
        return .result(value: report)
    }
}

// MARK: - Open Diagnostics (surfaces DiagnosticsView via App Intent)

@available(iOS 17.0, macOS 14.0, *)
public struct OpenDiagnosticsIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Diagnostics"
    public static let description = IntentDescription("Open the live diagnostics surface in Quicksilver.")
    public static let openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // openAppWhenRun = true is the primary surface.
        // Future: deep-link via URL or NotificationCenter if needed.
        return .result()
    }
}

// MARK: - Query Nexus (wired through IntelligenceSurface.ask)

@available(iOS 17.0, macOS 14.0, *)
public struct QueryNexusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ask Nexus"
    public static let description = IntentDescription("Send a short query to the Quicksilver intelligence layer.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Query")
    public var query: String

    public init() {}
    public init(query: String) {
        self.query = query
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let surface = try IntentDependencies.shared.requireSurface()
        let answer = try await surface.ask(query)
        // P-T6: never prefix with [Aspect] — Mercury is one being.
        return .result(value: LivingNarration.presentIntentAnswer(answer))
    }
}

// MARK: - App Shortcuts provider (≤ 10 hard limit)

@available(iOS 17.0, macOS 14.0, *)
public struct QuicksilverShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        // 1
        AppShortcut(
            intent: GetCurrentAspectIntent(),
            phrases: [
                "What aspect is active in \(.applicationName)",
                "Current aspect in \(.applicationName)",
                "Who is active in \(.applicationName)"
            ],
            shortTitle: "Current Aspect",
            systemImageName: "person.crop.circle"
        )
        // 2
        AppShortcut(
            intent: GetContextIntent(),
            phrases: [
                "What's the context in \(.applicationName)",
                "Status for \(.applicationName)",
                "How is \(.applicationName) doing"
            ],
            shortTitle: "Context",
            systemImageName: "info.circle"
        )
        // 4
        AppShortcut(
            intent: ReportStatusIntent(),
            phrases: [
                "Report status in \(.applicationName)",
                "Full diagnostics from \(.applicationName)",
                "Run diagnostics in \(.applicationName)"
            ],
            shortTitle: "Full Status",
            systemImageName: "waveform.path.ecg"
        )
        // 5
        AppShortcut(
            intent: OpenDiagnosticsIntent(),
            phrases: [
                "Open diagnostics in \(.applicationName)",
                "Show diagnostics in \(.applicationName)"
            ],
            shortTitle: "Open Diagnostics",
            systemImageName: "stethoscope"
        )
        // 6
        AppShortcut(
            intent: CaptureMemoryIntent(content: ""),
            phrases: [
                "Remember this in \(.applicationName)",
                "Capture memory in \(.applicationName)",
                "Note this in \(.applicationName)"
            ],
            shortTitle: "Remember",
            systemImageName: "brain.head.profile"
        )
        // 7
        AppShortcut(
            intent: QueryNexusIntent(query: ""),
            phrases: [
                "Ask Nexus in \(.applicationName)",
                "Ask \(.applicationName)",
                "Talk to \(.applicationName)"
            ],
            shortTitle: "Ask Nexus",
            systemImageName: "sparkles"
        )
    }
}
