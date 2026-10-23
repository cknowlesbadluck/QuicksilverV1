import XCTest
@testable import Core
@testable import Nexus

/// The five Nexus device sensors (Sense). Previously untested. Runs on the macOS SPM host:
/// UIKit-only paths (battery readings) are covered by their no-op contract.
@MainActor
final class DeviceMonitorTests: XCTestCase {

    // MARK: Battery

    func testBatteryDefaultsAndIdempotentLifecycle() {
        let monitor = BatteryMonitor()
        XCTAssertEqual(monitor.diagnosticID, "battery")
        XCTAssertEqual(monitor.level, -1, "unknown until UIDevice reports")
        XCTAssertEqual(monitor.stateDescription, "unknown")
        monitor.start()
        monitor.start()
        monitor.stop()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }

    // MARK: Storage

    func testStorageSamplesImmediatelyOnStart() {
        let monitor = StorageMonitor()
        XCTAssertEqual(monitor.diagnosticID, "storage")
        var calls: [(Double, Double)] = []
        monitor.onChange = { calls.append(($0, $1)) }
        monitor.start()
        defer { monitor.stop() }
        XCTAssertEqual(calls.count, 1)
        XCTAssertGreaterThan(monitor.totalGB, 0)
        XCTAssertGreaterThanOrEqual(monitor.availableGB, 0)
        XCTAssertLessThanOrEqual(monitor.availableGB, monitor.totalGB)
    }

    func testStorageStartIsIdempotentAndRestartsAfterStop() {
        let monitor = StorageMonitor()
        var calls = 0
        monitor.onChange = { _, _ in calls += 1 }
        monitor.start()
        monitor.start()
        XCTAssertEqual(calls, 1, "second start must not sample again")
        monitor.stop()
        monitor.start()
        XCTAssertEqual(calls, 2, "restart after stop samples again")
        monitor.stop()
    }

    // MARK: Network

    func testNetworkDeliversPathOnMainAfterStart() async {
        let monitor = NetworkMonitor()
        XCTAssertEqual(monitor.diagnosticID, "network")
        let delivered = expectation(description: "path update")
        delivered.assertForOverFulfill = false
        monitor.onChange = { connected, _, _ in
            MainActor.assertIsolated()
            XCTAssertEqual(connected, monitor.isConnected)
            delivered.fulfill()
        }
        monitor.start()
        await fulfillment(of: [delivered], timeout: 5)
        monitor.stop()
    }

    /// NWPathMonitor is single-use after cancel(); stop → start must build a fresh one.
    func testNetworkSurvivesStopStartCycle() async {
        let monitor = NetworkMonitor()
        monitor.start()
        monitor.stop()
        let again = expectation(description: "path update after restart")
        again.assertForOverFulfill = false
        monitor.onChange = { _, _, _ in again.fulfill() }
        monitor.start()
        await fulfillment(of: [again], timeout: 5)
        monitor.stop()
    }

    // MARK: Device metrics

    func testDeviceMetricsReportsCurrentStateOnStart() {
        let monitor = DeviceMetricsMonitor()
        XCTAssertEqual(monitor.diagnosticID, "device")
        var calls = 0
        monitor.onChange = { _, _ in calls += 1 }
        monitor.start()
        defer { monitor.stop() }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(["nominal", "fair", "serious", "critical"].contains(monitor.thermalStateDescription))
        XCTAssertEqual(monitor.isLowPowerMode, ProcessInfo.processInfo.isLowPowerModeEnabled)
    }

    func testDeviceMetricsFollowsPowerNotificationsUntilStopped() async throws {
        let monitor = DeviceMetricsMonitor()
        var calls = 0
        monitor.onChange = { _, _ in calls += 1 }
        monitor.start()
        // Let the observer tasks subscribe before posting.
        try await Task.sleep(nanoseconds: 200_000_000)
        NotificationCenter.default.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        let deadline = Date().addingTimeInterval(3)
        while calls < 2, Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(calls, 2, "power-state notification re-reads ProcessInfo")

        monitor.stop()
        NotificationCenter.default.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(calls, 2, "no updates after stop")
    }

    // MARK: Diagnostic events

    func testDiagnosticEventDefaults() {
        let event = DiagnosticEvent(title: "Storage low", detail: "2 GB free", source: .storage)
        XCTAssertEqual(event.severity, .info)
        XCTAssertNil(event.signalID)
        XCTAssertLessThan(abs(event.timestamp.timeIntervalSinceNow), 5)
        XCTAssertEqual(DiagnosticEvent.Severity.allCases, [.info, .notice, .warning, .critical])
    }

    func testDiagnosticEventEqualityIsByValue() {
        let id = UUID(), now = Date()
        let lhs = DiagnosticEvent(id: id, title: "t", detail: "d", severity: .warning, timestamp: now, source: .network)
        let rhs = DiagnosticEvent(id: id, title: "t", detail: "d", severity: .warning, timestamp: now, source: .network)
        XCTAssertEqual(lhs, rhs)
        XCTAssertNotEqual(lhs, DiagnosticEvent(title: "t", detail: "d", severity: .warning, timestamp: now, source: .network))
    }
}
