import Foundation

/// Durable, provider-neutral task state for work that must survive an agent session ending.
/// The store persists metadata and execution state, never credentials.
public actor IntegrationTaskStore {
    public enum TaskStatus: String, Codable, Sendable {
        case queued
        case running
        case paused
        case awaitingApproval
        case completed
        case failed
    }

    public struct TaskStep: Codable, Sendable, Hashable, Identifiable {
        public let id: UUID
        public let order: Int
        public let capability: IntegrationCapability
        public let connectorID: String
        public let provider: IntegrationProvider
        public var status: TaskStatus
        public var attemptCount: Int
        public var lastError: String?

        public init(
            order: Int,
            capability: IntegrationCapability,
            connectorID: String,
            provider: IntegrationProvider,
            status: TaskStatus = .queued
        ) {
            self.id = UUID()
            self.order = order
            self.capability = capability
            self.connectorID = connectorID
            self.provider = provider
            self.status = status
            self.attemptCount = 0
            self.lastError = nil
        }
    }

    public struct Task: Codable, Sendable, Hashable, Identifiable {
        public let id: UUID
        public let objective: String
        public let createdAt: Date
        public var updatedAt: Date
        public var status: TaskStatus
        public var currentStep: Int
        public var steps: [TaskStep]
        public var lastEventID: UUID?

        public init(id: UUID = UUID(), objective: String, steps: [TaskStep]) {
            self.id = id
            self.objective = objective
            self.createdAt = Date()
            self.updatedAt = Date()
            self.status = .queued
            self.currentStep = 0
            self.steps = steps
            self.lastEventID = nil
        }
    }

    private let fileURL: URL
    private var tasks: [UUID: Task] = [:]

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultURL()
        self.fileURL = url
        self.tasks = Self.load(from: url)
    }

    public func create(objective: String, steps: [TaskStep]) async throws -> Task {
        let task = Task(objective: objective, steps: steps)
        tasks[task.id] = task
        try persist()
        return task
    }

    public func task(id: UUID) -> Task? {
        tasks[id]
    }

    public func all() -> [Task] {
        tasks.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func update(_ task: Task) async throws {
        var copy = task
        copy.updatedAt = Date()
        tasks[copy.id] = copy
        try persist()
    }

    public func markPaused(id: UUID) async throws {
        guard var task = tasks[id] else { return }
        task.status = .paused
        task.updatedAt = Date()
        tasks[id] = task
        try persist()
    }

    public func resume(id: UUID) async throws -> Task? {
        guard var task = tasks[id] else { return nil }
        task.status = .queued
        task.updatedAt = Date()
        tasks[id] = task
        try persist()
        return task
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder().encode(tasks)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [UUID: Task] {
        guard let data = try? Data(contentsOf: url),
              let tasks = try? decoder().decode([UUID: Task].self, from: data) else {
            return [:]
        }
        return tasks
    }

    private static func defaultURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Quicksilver/Integration", isDirectory: true)
        .appendingPathComponent("tasks.json")
    }

    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
