import Foundation
import Synchronization

/// Free-budget awareness (ROADMAP 4a, innovation 4). The gateway reports how many cloud
/// requests are left today, as counts only, in `x-mercury-budget-remaining` and
/// `x-mercury-budget-limit`. The app shows that in the Codex and leans on the
/// on-device mind as the budget runs out.
public struct CloudBudget: Sendable, Equatable {
    public static let remainingHeader = "x-mercury-budget-remaining"
    public static let limitHeader = "x-mercury-budget-limit"

    public let remaining: Int
    public let limit: Int
    /// UTC day (`yyyy-MM-dd`) the gateway counts against; a reading from another day is stale.
    public let day: String

    public init(remaining: Int, limit: Int, day: String) {
        self.remaining = max(0, min(remaining, limit))
        self.limit = limit
        self.day = day
    }

    public var isExhausted: Bool { remaining == 0 }

    /// At or below 10% of the daily total (at least 1 request) counts as "near the limit".
    /// Deliberately includes 0: with no cloud fallback left, a second on-device attempt is the most valuable one.
    public var isNearLimit: Bool { remaining <= max(1, limit / 10) }

    public var label: String {
        isExhausted ? "Spent for today (on-device only)" : "\(remaining) of \(limit) left today"
    }

    /// Parses both headers. Both must be present and non-negative integers, with a positive limit.
    public static func parse(_ headers: [AnyHashable: Any], now: Date = Date()) -> CloudBudget? {
        func int(_ name: String) -> Int? {
            for (key, value) in headers {
                guard let key = key as? String, key.lowercased() == name else { continue }
                return Int(String(describing: value).trimmingCharacters(in: .whitespaces))
            }
            return nil
        }
        guard let remaining = int(remainingHeader), let limit = int(limitHeader),
              remaining >= 0, limit > 0 else { return nil }
        return CloudBudget(remaining: remaining, limit: limit, day: utcDay(now))
    }

    public static func utcDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

/// Latest budget reading, thread-safe. Readings from a previous UTC day are ignored
/// because the gateway resets at UTC midnight.
public final class CloudBudgetMonitor: Sendable {
    public static let shared = CloudBudgetMonitor()

    private let latest = Mutex<CloudBudget?>(nil)

    public init() {}

    public func record(_ budget: CloudBudget?) {
        guard let budget else { return }
        latest.withLock { $0 = budget }
    }

    public func current(now: Date = Date()) -> CloudBudget? {
        latest.withLock { value in
            guard let value, value.day == CloudBudget.utcDay(now) else { return nil }
            return value
        }
    }

    public func reset() {
        latest.withLock { $0 = nil }
    }
}

extension GatewayStreamTransport {
    /// Records the budget from each opened response into `monitor`, then passes the stream on unchanged.
    public func recordingBudget(into monitor: CloudBudgetMonitor) -> GatewayStreamTransport {
        let open = self.open
        return GatewayStreamTransport { request in
            let opened = try await open(request)
            monitor.record(opened.budget)
            return opened
        }
    }
}
