import Foundation

/// Event-driven live refresh for MainActor view models.
///
/// Registers a filtered, small-buffer `EventBus` stream, refreshes once right
/// after registration (so nothing published before registration is missed),
/// then refreshes on every relevant event. An optional slow fallback timer keeps
/// state fresh when a value can change without a corresponding event.
///
/// `refresh` should capture its owner weakly (`{ [weak self] in self?.refresh() }`)
/// so the returned task never keeps the owner alive. Cancel the task to stop.
public enum EventDrivenRefresh {

    @MainActor
    public static func start(
        eventBus: EventBus,
        bufferingNewest limit: Int = 1,
        fallbackInterval: Duration? = nil,
        where isRelevant: @escaping @Sendable (EventBus.Event) -> Bool,
        refresh: @escaping @MainActor @Sendable () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            let stream = await eventBus.events(bufferingNewest: limit, where: isRelevant)
            // Stream is registered; catch up on anything published before that.
            guard !Task.isCancelled else { return }
            refresh()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in stream {
                        guard !Task.isCancelled else { break }
                        await refresh()
                    }
                }
                if let fallbackInterval {
                    group.addTask {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: fallbackInterval)
                            guard !Task.isCancelled else { break }
                            await refresh()
                        }
                    }
                }
            }
        }
    }
}
