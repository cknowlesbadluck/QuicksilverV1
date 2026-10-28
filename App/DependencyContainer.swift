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
    let routingConfigStore: RoutingConfigStore
    let nexus: NexusCoordinator

    /// Spotlight opt-in for saved notes (off by default; M3.5-T9).
    @ObservationIgnored lazy var noteSpotlight = NoteSpotlightSync(
        flags: featureFlags, surface: brain, waitForMemoryLoad: true
    )

    /// Central intelligence coordinator. UI and Intents should prefer the Brain
    /// for complex reasoning instead of reaching into individual services.
    let brain: MercuryBrain

    init(
        memoryStore: MemoryStore? = nil,
        aiProvider: AIProvider? = nil,
        nexus: NexusCoordinator? = nil,
        routingConfigStore: RoutingConfigStore? = nil,
        defaults: UserDefaults = .standard,
        environment: AppEnvironment = .current,
        configuration: AppConfiguration = .shared
    ) {
        self.environment = environment
        self.configuration = configuration
        self.featureFlags = FeatureFlags(defaults: defaults)
        self.logger = LoggerService()
        self.eventBus = EventBus()

        self.personaManager = PersonaManager(
            eventBus: eventBus,
            logger: logger
        )

        let resolvedMemoryStore: MemoryStore
        if let memoryStore {
            resolvedMemoryStore = memoryStore
            logger.info("Memory backend: injected", category: logger.memory)
        } else if let swiftDataStore = try? SwiftDataMemoryStore() {
            resolvedMemoryStore = swiftDataStore
            logger.info("Memory backend: SwiftData", category: logger.memory)
        } else {
            resolvedMemoryStore = KeychainMemoryStore()
            logger.info("Memory backend: Keychain (SwiftData unavailable)", category: logger.memory)
        }
        self.memoryManager = MemoryManager(store: resolvedMemoryStore, eventBus: eventBus, logger: logger)

        self.routingConfigStore = routingConfigStore ?? RoutingConfigStore()

        self.aiService = AIService(
            provider: aiProvider,
            eventBus: eventBus,
            logger: logger,
            featureFlags: featureFlags,
            routingConfigStore: self.routingConfigStore
        )

        self.nexus = nexus ?? NexusCoordinator(logger: logger, eventBus: eventBus)

        // Mercury Brain sits above the individual services.
        self.brain = MercuryBrain(
            personaManager: personaManager,
            memoryManager: memoryManager,
            memoryIndex: EmbeddingIndex(),
            aiService: aiService,
            nexus: self.nexus,
            eventBus: eventBus,
            logger: logger, aspectContinuity: AspectContinuityStore(defaults: defaults)
        )

        IntentDependencies.shared.configure(surface: brain)

        self.nexus.updatePersonaContext(personaManager.activeConfiguration.id)
        self.nexus.start()

        // SideStore first-run: warm memory so Ask / Intents / Home don't wait
        // for MemoryView to open. Failures are logged inside MemoryManager.
        // Rebuild the embedding sidecar after load, then keep it on memoryDidUpdate.
        startMemoryLoad()

        logger.info(
            "DependencyContainer ready — Mercury Brain online — \(configuration.fullVersionString)",
            category: logger.general
        )
    }

    var activeConfiguration: PersonaConfiguration {
        personaManager.activeConfiguration
    }

    /// Loads memory, then starts the brain index and Spotlight. Spotlight reconciles only after
    /// a successful load (so an empty snapshot never replaces the index), then follows every note change.
    private func startMemoryLoad() {
        Task { [weak self] in
            guard let self else { return }
            await self.memoryManager.load()
            self.brain.startMemoryIndexSync()
            self.noteSpotlight.follow(self.eventBus)
            // A failed load leaves memory empty; never let that replace the index.
            // Opt-out removal is not gated and still runs on the next sync.
            guard self.memoryManager.lastFailure != .load else { return }
            await self.noteSpotlight.memoryDidLoad()
        }
    }
}
