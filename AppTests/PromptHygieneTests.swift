import XCTest
@testable import Quicksilver
import Core
import Memory
import ServicesAI
import Nexus
import Personas

/// M3-T12: memory and device context reach prompts only inside a delimited
/// "untrusted notes" block, each note capped at 180 characters.
@MainActor
final class PromptHygieneTests: XCTestCase {
    func testOnDeviceSystemPromptSnapshotsUntrustedNotesBlock() throws {
        var state = NexusState()
        state.overallHealthScore = 80
        state.batteryLevel = 0.5
        let long = String(repeating: "y", count: 400)
        let memory = [
            MemoryItem(key: "pref", category: .preference, value: "terse answers", createdAt: Self.day),
            MemoryItem(key: "long", category: .project, value: long, createdAt: Self.day)
        ]

        let prompt = BrainComposition.systemPrompt(
            base: "aspect body",
            bias: "",
            memory: memory,
            state: state,
            aspect: .quicksilver,
            destination: .onDevice
        )

        let block = try XCTUnwrap(Self.notesBlock(in: prompt))
        let expected = [
            UntrustedNotes.openTag,
            UntrustedNotes.preamble,
            PromptComposer.memorySectionTitle,
            "- (2026-09-25) [preference] terse answers",
            "- (2026-09-25) [project] " + String(repeating: "y", count: UntrustedNotes.itemCharCap),
            PromptComposer.deviceSectionTitle,
            "- health 80, battery 50%",
            UntrustedNotes.closeTag
        ].joined(separator: "\n")
        XCTAssertEqual(block, expected)
        XCTAssertFalse(prompt.contains(long))
    }

    func testCloudSystemPromptCarriesNoUntrustedNotes() {
        var state = NexusState()
        state.batteryLevel = 0.5
        let prompt = BrainComposition.systemPrompt(
            base: "aspect body",
            bias: "",
            memory: [MemoryItem(key: "pref", category: .preference, value: "terse answers")],
            state: state,
            aspect: .quicksilver,
            destination: .cloud
        )
        XCTAssertFalse(prompt.contains(UntrustedNotes.openTag))
        XCTAssertFalse(prompt.contains("terse answers"))
    }

    func testAskDirectProviderAppendixIsDelimitedAndCapped() async throws {
        let recorder = HygieneRecorder()
        let container = try makeContainer(provider: recorder)
        container.featureFlags.set("aiServiceEnabled", enabled: true)
        let longNote = "plan the day " + String(repeating: "z", count: 300)
        await container.brain.remember(longNote)

        _ = try await container.brain.ask("plan the day")

        let system = try XCTUnwrap(recorder.requests.last?.systemPrompt)
        let block = try XCTUnwrap(Self.notesBlock(in: system))
        let lines = block.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, UntrustedNotes.openTag)
        XCTAssertEqual(lines.dropFirst().first, UntrustedNotes.preamble)
        XCTAssertEqual(lines.last, UntrustedNotes.closeTag)
        XCTAssertTrue(lines.contains(CloudContextPolicy.memorySectionTitle))
        let notes = lines.filter { $0.hasPrefix("- ") }.map { String($0.dropFirst(2)) }
        XCTAssertFalse(notes.isEmpty)
        XCTAssertTrue(notes.allSatisfy { $0.count <= UntrustedNotes.itemCharCap })
        XCTAssertTrue(system.hasSuffix(UntrustedNotes.closeTag))
        XCTAssertFalse(system.contains(longNote))
    }

    private static let day: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 25)) ?? Date(timeIntervalSince1970: 0)
    }()

    private static func notesBlock(in prompt: String) -> String? {
        guard let open = prompt.range(of: UntrustedNotes.openTag) else { return nil }
        let tail = open.upperBound..<prompt.endIndex
        guard let close = prompt.range(of: UntrustedNotes.closeTag, range: tail) else { return nil }
        return String(prompt[open.lowerBound..<close.upperBound])
    }

    private func makeContainer(provider: AIProvider) throws -> DependencyContainer {
        let suiteName = "PromptHygieneTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        let logger = LoggerService(subsystem: "com.quicksilver.tests")
        let nexus = NexusCoordinator(
            networkMonitor: HygieneNetworkMonitor(),
            batteryMonitor: HygieneBatteryMonitor(),
            storageMonitor: HygieneStorageMonitor(),
            deviceMonitor: HygieneDeviceMonitor(),
            logger: logger,
            eventBus: EventBus()
        )
        return DependencyContainer(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: provider,
            nexus: nexus,
            defaults: defaults
        )
    }
}

private final class HygieneRecorder: AIProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [AIRequest] = []
    var requests: [AIRequest] { lock.withLock { _requests } }

    let id = "prompt-hygiene-recorder"
    let displayName = "PromptHygieneRecorder"
    let isAvailable = true
    let trainsOnPrompts = false

    func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.withLock { _requests.append(request) }
        return AIResponse(requestID: request.id, content: "ok")
    }
}

private final class HygieneNetworkMonitor: NetworkMonitoring {
    let diagnosticID = "network-test"
    var isConnected = true
    var isExpensive = false
    var isConstrained = false
    var onChange: ((Bool, Bool, Bool) -> Void)?
    func start() {}
    func stop() {}
}

private final class HygieneBatteryMonitor: BatteryMonitoring {
    let diagnosticID = "battery-test"
    var level = 1.0
    var stateDescription = "full"
    var onChange: ((Double, String) -> Void)?
    func start() {}
    func stop() {}
}

private final class HygieneStorageMonitor: StorageMonitoring {
    let diagnosticID = "storage-test"
    var availableGB = 100.0
    var totalGB = 128.0
    var onChange: ((Double, Double) -> Void)?
    func start() {}
    func stop() {}
}

private final class HygieneDeviceMonitor: DeviceMetricsMonitoring {
    let diagnosticID = "device-test"
    var thermalStateDescription = "nominal"
    var isLowPowerMode = false
    var onChange: ((String, Bool) -> Void)?
    func start() {}
    func stop() {}
}
