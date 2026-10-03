import Foundation

/// Client-side gateway stream timeouts (M3-T3).
/// Owned by AIRoutingConfig (M3-T4); defaults match ROADMAP M3-T3.
public struct GatewayTimeouts: Sendable, Equatable {
    /// TCP / TLS connect budget applied to the URLRequest.
    public var connect: TimeInterval
    /// Max wait for the first decoded SSE event after the response starts.
    public var firstEvent: TimeInterval
    /// Max silence between SSE events once streaming has begun.
    public var idle: TimeInterval
    /// Hard cap for the entire request/stream.
    public var total: TimeInterval

    public init(
        connect: TimeInterval = 10,
        firstEvent: TimeInterval = 20,
        idle: TimeInterval = 15,
        total: TimeInterval = 90
    ) {
        self.connect = connect
        self.firstEvent = firstEvent
        self.idle = idle
        self.total = total
    }

    public static let defaults = GatewayTimeouts()
}
