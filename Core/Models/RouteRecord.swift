import Foundation

/// Privacy/routing diagnostic: which route each recent turn took and why.
/// Stores **no content**: no prompt, reply, memory or context text, only the route, a fixed
/// reason code, an optional provider display name and a timestamp. It lives in memory only
/// (lost on relaunch) and is capped.
public struct RouteRecord: Sendable, Equatable, Identifiable {
    public enum Route: String, Sendable, Equatable {
        case onDevice
        case memoryRecall
        case cloudMinimal
        case cloudStandard
        case keptOnDevice
        case budgetSpent
        case failed
    }

    public let id: UUID
    public let date: Date
    public let route: Route
    /// Display name of the provider for cloud routes; nil otherwise.
    public let providerName: String?

    public init(id: UUID = UUID(), date: Date = Date(), route: Route, providerName: String? = nil) {
        self.id = id
        self.date = date
        self.route = route
        self.providerName = providerName
    }

    /// Fixed, content-free explanation for the Codex row.
    public var summary: String {
        switch route {
        case .onDevice: return "On device: nothing left the phone"
        case .memoryRecall: return "From saved notes on device: no model call"
        case .cloudMinimal: return "Cloud (\(providerName ?? "cloud")): minimal context, provider may train"
        case .cloudStandard: return "Cloud (\(providerName ?? "cloud")): standard context"
        case .keptOnDevice: return "Kept on device: personal turn, cloud blocked by the privacy gate"
        case .budgetSpent: return "Not sent: today's cloud budget is spent"
        case .failed: return "Failed: no reply"
        }
    }
}
