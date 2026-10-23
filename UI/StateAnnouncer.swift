import Foundation
import Observation
import Core
#if canImport(UIKit)
import UIKit
#endif

/// Speaks the Brain's state changes to VoiceOver users ("Thinking", "Answer ready"), which are
/// otherwise visible only as motion and colour. Express layer only: it reads the Brain-owned
/// `VisualState`, never sets it.
///
/// - Only while VoiceOver is running, and never under `-uitest` (the a11y audit and smoke runs).
/// - Rate-limited: at most one announcement per `minimumInterval`, so fast state churn
///   (thinking → processing → speaking) doesn't flood speech. Critical always speaks.
/// - Only meaningful states have a message; idle, transitioning and processing stay silent.
@MainActor
final class StateAnnouncer {
    static let minimumInterval: TimeInterval = 4

    private let read: @MainActor () -> VisualState
    private let post: @MainActor (String) -> Void
    private let now: @MainActor () -> Date
    private let isEnabled: @MainActor () -> Bool
    private var lastState: VisualState?
    private var lastSpokenAt: Date?
    private var isObserving = false
    /// Bumped on every start/stop so a tracking chain from an earlier start can't double up.
    private var generation = 0

    init(
        read: @escaping @MainActor () -> VisualState,
        post: @escaping @MainActor (String) -> Void = StateAnnouncer.postAnnouncement,
        now: @escaping @MainActor () -> Date = { Date() },
        isEnabled: @escaping @MainActor () -> Bool = StateAnnouncer.voiceOverIsRunning
    ) {
        self.read = read
        self.post = post
        self.now = now
        self.isEnabled = isEnabled
    }

    static func message(for state: VisualState) -> String? {
        switch state {
        case .listening: return "Listening"
        case .thinking: return "Thinking"
        case .speaking: return "Answering"
        case .success: return "Answer ready"
        case .warning: return "Needs attention"
        case .critical: return "Critical device condition"
        case .sleeping: return "Resting"
        case .idle, .processing, .transitioning: return nil
        }
    }

    /// Starts following the Brain's state (Observation, no polling). Idempotent.
    func start() {
        guard !isObserving else { return }
        isObserving = true
        generation += 1
        lastState = read()
        track(generation)
    }

    func stop() {
        isObserving = false
        generation += 1
    }

    /// Feeds one observed state. Internal for tests; `start()` calls it on every change.
    func observe(_ state: VisualState) {
        defer { lastState = state }
        guard state != lastState, isEnabled(), let message = Self.message(for: state) else { return }
        let time = now()
        if state != .critical, let last = lastSpokenAt, time.timeIntervalSince(last) < Self.minimumInterval {
            return
        }
        lastSpokenAt = time
        post(message)
    }

    private func track(_ chain: Int) {
        withObservationTracking {
            _ = read()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isObserving, chain == self.generation else { return }
                self.observe(self.read())
                self.track(chain)
            }
        }
    }

    static func postAnnouncement(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    static func voiceOverIsRunning() -> Bool {
        #if canImport(UIKit)
        return UIAccessibility.isVoiceOverRunning && !UITestLaunch.isActive
        #else
        return false
        #endif
    }
}
