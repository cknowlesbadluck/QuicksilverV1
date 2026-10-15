import Foundation
import Network
import Core

/// Network path monitor using NWPathMonitor (public API only).
///
/// Isolation (issue #252): `@MainActor` with an isolated conformance, replacing
/// `@unchecked Sendable`. NWPathMonitor delivers on a private queue; the handler
/// hops to the main actor before mutating state or invoking onChange.
///
/// Lifecycle: `NWPathMonitor` is single-use after `cancel()`. `start()` always
/// constructs a fresh monitor so stop → start cycles (backgrounding, Nexus restart) work.
@MainActor
public final class NetworkMonitor: @MainActor NetworkMonitoring {
    public var diagnosticID: String { "network" }

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "com.quicksilver.nexus.network", qos: .utility)
    private var isRunning = false

    public private(set) var isConnected = false
    public private(set) var isExpensive = false
    public private(set) var isConstrained = false
    public var onChange: ((Bool, Bool, Bool) -> Void)?

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        let pathMonitor = NWPathMonitor()
        monitor = pathMonitor

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            // Deliver on main so NexusCoordinator (MainActor) sees consistent state.
            Task { @MainActor [weak self] in
                self?.apply(connected: connected, expensive: expensive, constrained: constrained)
            }
        }
        pathMonitor.start(queue: queue)
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        monitor?.cancel()
        monitor?.pathUpdateHandler = nil
        monitor = nil
    }

    private func apply(connected: Bool, expensive: Bool, constrained: Bool) {
        isConnected = connected
        isExpensive = expensive
        isConstrained = constrained
        onChange?(connected, expensive, constrained)
    }

    deinit {
        monitor?.cancel()
    }
}
