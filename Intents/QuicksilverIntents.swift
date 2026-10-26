import AppIntents
import Foundation
import Core
import Personas

// MARK: - Input hygiene

enum IntentInput {
    /// Removes control and format characters (NUL, ESC, bidi overrides, zero-width marks) that a
    /// Shortcut can pass from a clipboard, keeping newlines and tabs, then trims whitespace.
    static func clean(_ text: String) -> String {
        let kept = text.unicodeScalars.filter { scalar in
            if scalar == "\n" || scalar == "\t" { return true }
            switch scalar.properties.generalCategory {
            case .control, .format: return false
            default: return true
            }
        }
        return String(String.UnicodeScalarView(kept)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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
        let trimmed = IntentInput.clean(content)
        guard !trimmed.isEmpty else {
            throw $content.needsValueError("What should Quicksilver remember?")
        }
        let surface = try IntentDependencies.shared.requireSurface()
        let truncated = String(trimmed.prefix(500))
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
    /// Longest query sent on. Shortcuts can pass arbitrarily long text (a whole clipboard);
    /// the cap keeps one intent call bounded, like `CaptureMemoryIntent`'s 500.
    public static let maxQueryLength = 2_000

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
        let trimmed = IntentInput.clean(query)
        guard !trimmed.isEmpty else {
            throw $query.needsValueError("What would you like to ask?")
        }
        let surface = try IntentDependencies.shared.requireSurface()
        let answer = try await surface.ask(String(trimmed.prefix(Self.maxQueryLength)))
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
            // No pre-filled value: Siri/Shortcuts prompts for the content.
            intent: CaptureMemoryIntent(),
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
            // No pre-filled value: Siri/Shortcuts prompts for the query.
            intent: QueryNexusIntent(),
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
