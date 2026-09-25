import Foundation

public struct NexusState: Sendable, Equatable {
    public var isActive: Bool = false
    public var lastUpdated: Date = Date()
    public var networkStatus: String = "unknown"
    public var isNetworkExpensive: Bool = false
    public var isNetworkConstrained: Bool = false
    public var batteryLevel: Double?
    public var batteryState: String = "unknown"
    public var availableStorageGB: Double?
    public var totalStorageGB: Double?
    public var thermalState: String = "unknown"
    public var lowPowerMode: Bool = false
    public var recentSignals: [Signal] = []
    public var recentEvents: [DiagnosticEvent] = []
    public var recentInsights: [Insight] = []
    public var networkHealthScore: Int = 100
    public var powerHealthScore: Int = 100
    public var overallHealthScore: Int = 100

    public init() {}

    public mutating func appendSignal(_ signal: Signal, maxHistory: Int = 50) {
        recentSignals.insert(signal, at: 0)
        if recentSignals.count > maxHistory { recentSignals = Array(recentSignals.prefix(maxHistory)) }
        lastUpdated = Date()
    }

    public mutating func appendEvent(_ event: DiagnosticEvent, maxHistory: Int = 30) {
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxHistory { recentEvents = Array(recentEvents.prefix(maxHistory)) }
        lastUpdated = Date()
    }

    public mutating func appendInsight(_ insight: Insight, maxHistory: Int = 20) {
        recentInsights.insert(insight, at: 0)
        if recentInsights.count > maxHistory { recentInsights = Array(recentInsights.prefix(maxHistory)) }
        lastUpdated = Date()
    }
}

public struct Insight: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let body: String
    public let severity: DiagnosticEvent.Severity
    public let relatedSignalIDs: [UUID]
    public let personaStyle: String
    public let timestamp: Date
    public let suggestedAction: String?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        severity: DiagnosticEvent.Severity = .info,
        relatedSignalIDs: [UUID] = [],
        personaStyle: String,
        timestamp: Date = Date(),
        suggestedAction: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.severity = severity
        self.relatedSignalIDs = relatedSignalIDs
        self.personaStyle = personaStyle
        self.timestamp = timestamp
        self.suggestedAction = suggestedAction
    }
}
