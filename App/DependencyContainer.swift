import Foundation
import SwiftUI
import Observation
import Core
import Personas
import Memory
import ServicesAI
import Nexus
import QuicksilverIntents

@MainActor
@Observable
final class DependencyContainer {
    let environment: AppEnvironment
    let configuration: AppConfiguration
    let featureFlags: FeatureFlags
    let logger: LoggerService
    let eventBus: EventBus
    let personaManager: PersonaManager
    let memoryManager: MemoryManager
    let aiService: AIService
    let nexus: NexusCoordinator

    /// Central intelligence coordinator. UI and Intents should prefer the Brain
    /// for complex reasoning instead of reaching into individual services.
    let brain: MercuryBrain

    init(environment: AppEnvironment = .current, configuration: AppConfiguration = .shared) {
        self.environment = environment
        self.configuration = configuration
        self.featureFlags = FeatureFlags()
        self.logger = LoggerService()
        self.eventBus = EventBus()

        self.personaManager = PersonaManager(
            eventBus: eventBus,
            logger: logger
        )

        let memoryStore: MemoryStore
        if let swiftDataStore = try? SwiftDataMemoryStore() {
            memoryStore = swiftDataStore
            logger.info("Memory backend: SwiftData", category: logger.memory)
        } else {
            memoryStore = KeychainMemoryStore()
            logger.info("Memory backend: Keychain (SwiftData unavailable)", category: logger.memory)
        }
        self.memoryManager = MemoryManager(store: memoryStore, eventBus: eventBus, logger: logger)

        let (primary, secondary) = Self.makeConfiguredProviders()
        self.aiService = AIService(
            primary: primary,
            secondary: secondary,
            eventBus: eventBus,
            logger: logger,
            featureFlags: featureFlags
        )

        self.nexus = NexusCoordinator(logger: logger, eventBus: eventBus)

        // Mercury Brain sits above the individual services
        self.brain = MercuryBrain(
            personaManager: personaManager,
            memoryManager: memoryManager,
            aiService: aiService,
            nexus: nexus,
            eventBus: eventBus,
            logger: logger
        )

        IntentDependencies.shared.configure(surface: brain)

        nexus.updatePersonaContext(personaManager.activeConfiguration.id)
        nexus.start()

        // SideStore first-run: warm memory so Ask / Intents / Home don't wait
        // for MemoryView to open. Failures are logged inside MemoryManager.
        Task { await memoryManager.load() }

        logger.info("DependencyContainer ready — Mercury Brain online — \(configuration.fullVersionString)", category: logger.general)
    }

    /// Test and preview seam. The production `init` is unchanged and still
    /// owns sensor start plus memory warm-up. This path does not start Nexus
    /// and does not read the production Keychain or `UserDefaults.standard`.
    /// Injected Nexus and PersonaManager share the same EventBus.
    init(
        memoryStore: MemoryStore,
        aiProvider: AIProvider?,
        nexus: NexusCoordinator,
        defaults: UserDefaults
    ) {
        self.environment = .current
        self.configuration = .shared
        self.featureFlags = FeatureFlags(defaults: defaults)
        self.logger = LoggerService()
        self.eventBus = EventBus()
        self.personaManager = PersonaManager(eventBus: eventBus, logger: logger)
        self.memoryManager = MemoryManager(store: memoryStore, eventBus: eventBus, logger: logger)
        self.aiService = AIService(
            primary: aiProvider as? Provider,
            secondary: nil,
            eventBus: eventBus,
            logger: logger,
            featureFlags: featureFlags
        )
        self.nexus = nexus
        self.brain = MercuryBrain(
            personaManager: personaManager,
            memoryManager: memoryManager,
            aiService: aiService,
            nexus: nexus,
            eventBus: eventBus,
            logger: logger
        )

        IntentDependencies.shared.configure(surface: brain)
        logger.info(
            "DependencyContainer injected — sensors left stopped",
            category: logger.general
        )
    }

    private static func makeConfiguredProviders() -> (primary: Provider, secondary: Provider?) {
        // Load from Codex or defaults
        let primary: Provider = GeminiProvider() // or from configuration
        return (primary, nil)
    }

    var activeConfiguration: PersonaConfiguration {
        personaManager.activeConfiguration
    }
}
