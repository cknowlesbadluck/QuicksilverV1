import Foundation
import Core

/// Storage pressure monitor using FileManager (public API only).
/// Main-actor isolated (issue #252): replaces `@unchecked Sendable`. All state
/// mutation and callbacks already happened on the main queue; now the compiler checks it.
/// The conformance is isolated (`@MainActor StorageMonitoring`); NexusCoordinator,
/// its only owner, is `@MainActor`.
@MainActor
public final class StorageMonitor: @MainActor StorageMonitoring {
    public var diagnosticID: String { "storage" }

    private var isRunning = false
    /// Sampling loop. `Task` is Sendable, so the nonisolated deinit may cancel it.
    private var sampler: Task<Void, Never>?
    public private(set) var availableGB: Double = 0
    public private(set) var totalGB: Double = 0
    public var onChange: ((Double, Double) -> Void)?

    public init() {}

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        sample()
        sampler?.cancel()
        sampler = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(120))
                guard !Task.isCancelled else { return }
                self?.sample()
            }
        }
    }

    public func stop() {
        isRunning = false
        sampler?.cancel()
        sampler = nil
    }

    deinit {
        sampler?.cancel()
    }

    private func sample() {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let free = attrs[.systemFreeSize] as? NSNumber,
               let total = attrs[.systemSize] as? NSNumber {
                availableGB = free.doubleValue / 1_073_741_824
                totalGB = total.doubleValue / 1_073_741_824
                onChange?(availableGB, totalGB)
            }
        } catch {
            // Best-effort; storage sampling must never crash the app.
        }
    }
}
