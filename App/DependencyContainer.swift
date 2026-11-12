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
    /// Which memory store opened this session (M4-T5 backup-store disclosure).
    let memoryBackend: MemoryBackend
    let aiService: AIService
    let routingConfigStore: RoutingConfigStore
    let nexus: NexusCoordinator
    @ObservationIgnored private var memoryLoadRetryTask: Task<Void, Never>?
    @ObservationIgnored private var memoryIndexSyncStarted = false

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

        let (resolvedMemoryStore, backend) = Self.resolveMemoryStore(injected: memoryStore, logger: logger)
        self.memoryBackend = backend
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
            self.noteSpotlight.follow(self.eventBus)
            // Never replace a valid Spotlight index with an empty snapshot after a failed read.
            if self.memoryManager.lastFailure == .load {
                await self.retrySpotlightMemoryLoad()
            } else {
                await self.memoryLoadDidSucceed()
            }
        }
    }

    /// Complete memory-load-dependent indexes exactly once, including recovery paths.
    func memoryLoadDidSucceed() async {
        memoryLoadRetryTask?.cancel()
        memoryLoadRetryTask = nil
        if !memoryIndexSyncStarted {
            brain.startMemoryIndexSync()
            memoryIndexSyncStarted = true
        }
        await noteSpotlight.memoryLoadSucceeded()
    }

    /// Reopen the Spotlight readiness gate after a transient initial memory-store failure.
    /// Retry on a short bounded schedule, then wait for a memory write (e.g. from Shortcuts).
    private func retrySpotlightMemoryLoad() async {
        let stream = await eventBus.events(bufferingNewest: 1) { event in
            if case .memoryDidUpdate = event { return true }
            return false
        }
        memoryLoadRetryTask?.cancel()
        let (triggers, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let eventListener = Task {
            for await _ in stream {
                guard !Task.isCancelled else { break }
                continuation.yield(())
            }
        }
        let timer = Task {
            for delay in [1, 3, 10] {
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                guard !Task.isCancelled else { return }
                continuation.yield(())
            }
        }
        memoryLoadRetryTask = Task { [weak self] in
            for await _ in triggers {
                guard !Task.isCancelled, let self, !self.noteSpotlight.isMemoryReady else { break }
                await self.memoryManager.load()
                if self.memoryManager.lastFailure != .load {
                    await self.memoryLoadDidSucceed()
                    break
                }
            }
            eventListener.cancel()
            timer.cancel()
            continuation.finish()
        }
    }
}

extension DependencyContainer {
    /// Injected store, else SwiftData, else the Keychain backup (disclosed in the Memory screen, M4-T5).
    static func resolveMemoryStore(injected: MemoryStore?, logger: LoggerService) -> (MemoryStore, MemoryBackend) {
        if let injected {
            logger.info("Memory backend: injected", category: logger.memory)
            return (injected, .injected)
        }
        if let swiftDataStore = try? SwiftDataMemoryStore() {
            logger.info("Memory backend: SwiftData", category: logger.memory)
            return (swiftDataStore, .swiftData)
        }
        logger.info("Memory backend: Keychain (SwiftData unavailable)", category: logger.memory)
        return (KeychainMemoryStore(), .keychainFallback)
    }
}
