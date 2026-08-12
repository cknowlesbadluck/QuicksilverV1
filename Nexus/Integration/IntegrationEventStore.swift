import Foundation

/// Append-only local ledger for orchestration events.
/// Payloads are metadata only and must never contain secrets.
public actor IntegrationEventStore {
    public struct Event: Codable, Sendable, Hashable, Identifiable {
        public let id: UUID
        public let taskID: UUID
        public let timestamp: Date
        public let type: String
        public let provider: IntegrationProvider?
        public let message: String

        public init(
            taskID: UUID,
            type: String,
            provider: IntegrationProvider? = nil,
            message: String
        ) {
            self.id = UUID()
            self.taskID = taskID
            self.timestamp = Date()
            self.type = type
            self.provider = provider
            self.message = message
        }
    }

    private let fileURL: URL
    private var events: [Event] = []

    public init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultURL()
        self.fileURL = url
        if let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder().decode([Event].self, from: data) {
            events = decoded
        }
    }

    @discardableResult
    public func append(_ event: Event) async throws -> Event {
        events.append(event)
        try persist()
        return event
    }

    public func events(for taskID: UUID) -> [Event] {
        events
            .filter { $0.taskID == taskID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    public func recent(limit: Int = 100) -> [Event] {
        Array(events.suffix(max(0, limit)))
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try Self.encoder().encode(events)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Quicksilver/Integration", isDirectory: true)
        .appendingPathComponent("events.json")
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
