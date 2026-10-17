import Observation
import XCTest
@testable import Quicksilver
import Core

/// VoiceOver announcements of Brain state: meaningful states only, rate-limited, critical
/// always speaks, silent when VoiceOver is off, and driven by Observation.
/// Internal (not private): the @Observable macro's generated extension can't see private nested types.
@MainActor
@Observable
final class StateAnnouncerFakeBrain {
    var visualState: VisualState = .idle
}

@MainActor
final class StateAnnouncerTests: XCTestCase {
    private var spoken: [String] = []
    private var clock = Date(timeIntervalSince1970: 1_000)

    private func announcer(enabled: Bool = true, brain: StateAnnouncerFakeBrain = StateAnnouncerFakeBrain()) -> StateAnnouncer {
        StateAnnouncer(
            read: { brain.visualState },
            post: { [unowned self] in self.spoken.append($0) },
            now: { [unowned self] in self.clock },
            isEnabled: { enabled }
        )
    }

    func testMeaningfulStatesSpeakAndQuietOnesDont() {
        let subject = announcer()
        subject.observe(.idle)
        subject.observe(.thinking)
        clock += 10
        subject.observe(.processing)
        clock += 10
        subject.observe(.success)
        XCTAssertEqual(spoken, ["Thinking", "Answer ready"])
    }

    func testRepeatedStateIsSpokenOnce() {
        let subject = announcer()
        subject.observe(.thinking)
        clock += 10
        subject.observe(.thinking)
        XCTAssertEqual(spoken, ["Thinking"])
    }

    func testRateLimitDropsFastChurnButNotCritical() {
        let subject = announcer()
        subject.observe(.thinking)
        clock += 1
        subject.observe(.speaking)          // within the window: dropped
        clock += 1
        subject.observe(.critical)          // always speaks
        clock += StateAnnouncer.minimumInterval
        subject.observe(.success)
        XCTAssertEqual(spoken, ["Thinking", "Critical device condition", "Answer ready"])
    }

    func testSilentWhenVoiceOverIsOff() {
        let subject = announcer(enabled: false)
        subject.observe(.thinking)
        subject.observe(.critical)
        XCTAssertTrue(spoken.isEmpty)
    }

    func testEveryStateHasADecision() {
        let speaking = VisualState.allCases.filter { StateAnnouncer.message(for: $0) != nil }
        XCTAssertEqual(Set(speaking), [.listening, .thinking, .speaking, .success, .warning, .critical, .sleeping])
    }

    func testFollowsBrainStateThroughObservation() async throws {
        let brain = StateAnnouncerFakeBrain()
        let subject = announcer(brain: brain)
        subject.start()
        subject.start() // idempotent: no duplicate chain
        brain.visualState = .thinking
        try await waitFor { self.spoken == ["Thinking"] }
        clock += 10
        brain.visualState = .success
        try await waitFor { self.spoken == ["Thinking", "Answer ready"] }

        subject.stop()
        clock += 10
        brain.visualState = .warning
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(spoken, ["Thinking", "Answer ready"], "silent after stop")
    }

    func testDefaultGateIsClosedWithoutVoiceOver() {
        // CI runs without VoiceOver, so the production gate is closed here.
        XCTAssertFalse(StateAnnouncer.voiceOverIsRunning())
    }

    private func waitFor(_ condition: @escaping () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertTrue(condition())
    }
}
