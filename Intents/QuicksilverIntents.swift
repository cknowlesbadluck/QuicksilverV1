import AppIntents
import Foundation
import Core
import Personas
import ServicesAI

// MARK: - Get Current Persona (primary read surface)

@available(iOS 17.0, macOS 14.0, *)
public struct GetCurrentPersonaIntent: AppIntent {
    public static let title: LocalizedStringResource = "Get Current Persona"
    public static let description = IntentDescription("Returns the persona currently active in Quicksilver (autonomously chosen or overridden).")
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let manager = IntentDependencies.shared.personaManager else {
            throw AppError.nexusNotReady
        }
        let name = manager.activeConfiguration.displayName
        let id = manager.activeConfiguration.id
        return .result(value: "\(name) (\(id))")
    }
}

// MARK: - Force Persona (explicit override — uses PersonaEntity)

@available(iOS 17.0, macOS 14.0, *)
public struct ForcePersonaIntent: AppIntent {
    public static let title: LocalizedStringResource = "Force Persona"
    public static let description = IntentDescription("Manually override the autonomous persona selection. Use sparingly.")
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Persona")
    public var persona: PersonaEntity

    public init() {}
    public init(persona: PersonaEntity) {
        self.persona = persona
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let manager = IntentDependencies.shared.personaManager else {
            throw AppError.nexusNotReady
        }
        try await manager.switchTo(id: persona.id.lowercased())
        return .result(value: "Forced to \(manager.activeConfiguration.displayName)")
    }
}

// MARK: - Switch to Forge (high-frequency shortcut)

@available(iOS 17.0, macOS 14.0, *)
public struct SwitchToForgeIntent: AppIntent {
    public static let title: LocalizedStringResource = "Switch to Forge"
    public static let description = IntentDescription("Immediately activate the Forge persona for building and engineering work.")
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let manager = IntentDependencies.shared.personaManager else {
            throw AppError.nexusNotReady
        }
        try await manager.switchTo(id: "forge")
        return .result(value: "Forge is now active")
    }
}

// MARK: - Capture Memory (now actually persists)

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
        guard let manager = IntentDependencies.shared.personaManager,
              let memory = IntentDependencies.shared.memoryManager else {
            throw AppError.nexusNotReady
        }

        let truncated = String(content.prefix(500))
        let personaID = manager.activeConfiguration.id
        let policy = manager.activeMemoryPolicy

        manager.updateTaskContext(
            description: "Capture memory: \(String(truncated.prefix(80)))",
            kind: .reflecting,
            queryIntent: .reflective,
            memoryHints: [String(truncated.prefix(120))]
        )

        await memory.set(
            key: "note.intent.\(UUID().uuidString.prefix(8))",
            value: truncated,
            category: .temporary,
            metadata: ["source": "appintent", "persona": personaID],
            importanceBoost: policy.writeImportanceHint,
            personaScope: personaID
        )

        if let logger = IntentDependencies.shared.logger {
            logger.info("Memory capture persisted: \(truncated.prefix(60))", category: logger.memory)
        }
        return .result(value: "Captured: \(truncated)")
    }
}

// MARK: - Get Context

@available(iOS 17.0, macOS 14.0, *)
public struct GetContextIntent: AppIntent {
    public static let title: LocalizedStringResource = "What's the Context"
    public static let description = IntentDescription("Returns a short summary of current Quicksilver state (persona + health signals).")
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let manager = IntentDependencies.shared.personaManager,
              let nexus = IntentDependencies.shared.nexusCoordinator else {
            throw AppError.nexusNotReady
        }
        let persona = manager.activeConfiguration.displayName
        let health = nexus.state.overallHealthScore
        let battery = nexus.state.batteryLevel.map { "\(Int($0 * 100))%" } ?? "unknown"
        let network = nexus.state.networkStatus
        return .result(value: "Persona: \(persona) | Health: \(health) | Battery: \(battery) | Network: \(network)")
    }
}

// MARK: - Report Status (uses AutomationBridge)

@available(iOS 17.0, macOS 14.0, *)
public struct ReportStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Report Quicksilver Status"
    public static let description = IntentDescription("Full diagnostic report from Nexus (network, battery, health).")
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard let nexus = IntentDependencies.shared.nexusCoordinator else {
            throw AppError.nexusNotReady
        }
        let report = try nexus.bridge.triggerDiagnostic(named: "full")
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

// MARK: - Query Nexus (wired to AIService)

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
        guard let manager = IntentDependencies.shared.personaManager,
              let ai = IntentDependencies.shared.aiService else {
            throw AppError.nexusNotReady
        }

        let lower = query.lowercased()
        let intent: QueryIntent
        let kind: TaskKind

        if containsAny(lower, ["architect", "implement", "refactor", "debug", "error", "crash", "fix", "structure", "precision"]) {
            intent = .preciseTechnical
            kind = .building
        } else if containsAny(lower, ["reflect", "remember", "history", "pattern", "long-term", "why did", "continuity"]) {
            intent = .reflective
            kind = .reflecting
        } else if containsAny(lower, ["idea", "brainstorm", "what if", "explore", "creative", "option", "strategy"]) {
            intent = .creative
            kind = .exploring
        } else if containsAny(lower, ["diagnose", "why is", "broken", "failing"]) {
            intent = .diagnostic
            kind = .debugging
        } else {
            intent = .strategic
            kind = .exploring
        }

        manager.updateTaskContext(
            description: query,
            kind: kind,
            queryIntent: intent
        )

        let config = manager.activeConfiguration
        let response = try await ai.complete(
            prompt: query,
            systemPrompt: config.systemPrompt,
            temperature: config.preferredTemperature,
            maxTokens: config.maxTokensHint
        )

        return .result(value: "[\(config.displayName)] \(response.content)")
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }
}

// MARK: - App Shortcuts provider (≤ 10 hard limit)

@available(iOS 17.0, macOS 14.0, *)
public struct QuicksilverShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    public static var appShortcuts: [AppShortcut] {
        // 1
        AppShortcut(
            intent: GetCurrentPersonaIntent(),
            phrases: [
                "What persona is active in \(.applicationName)",
                "Current persona in \(.applicationName)",
                "Who is active in \(.applicationName)"
            ],
            shortTitle: "Current Persona",
            systemImageName: "person.crop.circle"
        )
        // 2
        AppShortcut(
            intent: SwitchToForgeIntent(),
            phrases: [
                "Switch to Forge in \(.applicationName)",
                "Activate Forge persona in \(.applicationName)",
                "Start building with Forge in \(.applicationName)"
            ],
            shortTitle: "Switch to Forge",
            systemImageName: "hammer.fill"
        )
        // 3
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
        // ForcePersonaIntent remains available in the Shortcuts app and via Siri
        // but is intentionally not promoted to an App Shortcut so we stay under the 10 limit
        // and keep the highest-frequency actions in the automatic surface.
    }
}
