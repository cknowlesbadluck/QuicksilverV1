import Foundation

/// Abstract budget for a single intelligence turn.
/// Prevents unbounded context growth and makes token / time / call limits explicit.
/// Pure value — the Broker (future) is the only consumer that enforces it.
public struct ResourcePlan: Sendable, Equatable {
    public let maxContextTokens: Int
    public let maxOutputTokens: Int
    public let maxWallClockSeconds: TimeInterval
    public let allowExternalCalls: Bool
    public let priority: Priority

    public init(
        maxContextTokens: Int = 8_192,
        maxOutputTokens: Int = 1_024,
        maxWallClockSeconds: TimeInterval = 45,
        allowExternalCalls: Bool = true,
        priority: Priority = .normal
    ) {
        self.maxContextTokens = max(0, maxContextTokens)
        self.maxOutputTokens = max(0, maxOutputTokens)
        self.maxWallClockSeconds = max(1, maxWallClockSeconds)
        self.allowExternalCalls = allowExternalCalls
        self.priority = priority
    }

    public enum Priority: String, Sendable, Equatable, CaseIterable {
        case low
        case normal
        case high
        case critical
    }

    /// Conservative plan for background / Nexus-driven work.
    public static let background = ResourcePlan(
        maxContextTokens: 2_048,
        maxOutputTokens: 256,
        maxWallClockSeconds: 15,
        allowExternalCalls: false,
        priority: .low
    )

    /// Default interactive plan (user-initiated Ask / create).
    public static let interactive = ResourcePlan()

    /// Elevated plan for Forge / diagnostic depth.
    public static let elevated = ResourcePlan(
        maxContextTokens: 16_384,
        maxOutputTokens: 2_048,
        maxWallClockSeconds: 90,
        allowExternalCalls: true,
        priority: .high
    )
}
