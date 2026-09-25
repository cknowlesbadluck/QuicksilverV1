import Foundation

public struct DiagnosticEvent: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let signalID: UUID?
    public let title: String
    public let detail: String
    public let severity: Severity
    public let timestamp: Date
    public let source: Signal.Source

    public enum Severity: String, Sendable, CaseIterable {
        case info, notice, warning, critical
    }

    public init(
        id: UUID = UUID(),
        signalID: UUID? = nil,
        title: String,
        detail: String,
        severity: Severity = .info,
        timestamp: Date = Date(),
        source: Signal.Source
    ) {
        self.id = id
        self.signalID = signalID
        self.title = title
        self.detail = detail
        self.severity = severity
        self.timestamp = timestamp
        self.source = source
    }
}
