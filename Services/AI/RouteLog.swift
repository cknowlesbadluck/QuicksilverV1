import Foundation
import Synchronization
import Core

public final class RouteLog: Sendable {
    public static let shared = RouteLog()
    public static let capacity = 20

    private let records = Mutex<[RouteRecord]>([])

    public init() {}

    public func record(_ record: RouteRecord) {
        records.withLock { list in
            list.append(record)
            if list.count > Self.capacity { list.removeFirst(list.count - Self.capacity) }
        }
    }

    /// Newest first.
    public func recent(limit: Int = RouteLog.capacity) -> [RouteRecord] {
        records.withLock { Array($0.suffix(limit).reversed()) }
    }

    public func clear() {
        records.withLock { $0.removeAll() }
    }
}

extension AIService {
    public var routeLog: RouteLog { .shared }

    func recordRoute(_ provenance: AnswerProvenance, trainsOnPrompts: Bool) {
        switch provenance.origin {
        case .onDevice, .memory:
            routeLog.record(RouteRecord(route: .onDevice))
        case .cloud:
            routeLog.record(RouteRecord(
                route: trainsOnPrompts ? .cloudMinimal : .cloudStandard,
                providerName: provenance.providerName
            ))
        }
    }

    func recordRoute(failure error: Error) {
        if AIClientClassifier.isCancellation(error) { return }
        switch error as? AppError {
        case .keptOnDevice?: routeLog.record(RouteRecord(route: .keptOnDevice))
        case .budgetExhausted?: routeLog.record(RouteRecord(route: .budgetSpent))
        default: routeLog.record(RouteRecord(route: .failed))
        }
    }
}
