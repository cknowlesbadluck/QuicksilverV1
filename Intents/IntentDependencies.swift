import Foundation
import Core
import Personas
import Nexus
import Memory
import ServicesAI

/// Process-wide dependency registry for App Intents.
/// App Intents are system-instantiated and cannot receive constructor injection.
@MainActor
public final class IntentDependencies {
    public static let shared = IntentDependencies()

    public private(set) var personaManager: PersonaManager?
    public private(set) var nexusCoordinator: NexusCoordinator?
    public private(set) var memoryManager: MemoryManager?
    public private(set) var aiService: AIService?
    public private(set) var eventBus: EventBus?
    public private(set) var logger: LoggerService?

    public var isConfigured: Bool {
        personaManager != nil && nexusCoordinator != nil && aiService != nil
    }

    public struct Configuration {
        public let personaManager: PersonaManager
        public let nexusCoordinator: NexusCoordinator
        public let memoryManager: MemoryManager
        public let aiService: AIService
        public let eventBus: EventBus
        public let logger: LoggerService

        public init(
            personaManager: PersonaManager,
            nexusCoordinator: NexusCoordinator,
            memoryManager: MemoryManager,
            aiService: AIService,
            eventBus: EventBus,
            logger: LoggerService
        ) {
            self.personaManager = personaManager
            self.nexusCoordinator = nexusCoordinator
            self.memoryManager = memoryManager
            self.aiService = aiService
            self.eventBus = eventBus
            self.logger = logger
        }
    }

    private init() {}

    public func configure(_ configuration: Configuration) {
        guard !isConfigured else { return }
        personaManager = configuration.personaManager
        nexusCoordinator = configuration.nexusCoordinator
        memoryManager = configuration.memoryManager
        aiService = configuration.aiService
        eventBus = configuration.eventBus
        logger = configuration.logger
    }

    func resetForTesting() {
        personaManager = nil
        nexusCoordinator = nil
        memoryManager = nil
        aiService = nil
        eventBus = nil
        logger = nil
    }
}
