import XCTest
@testable import Core

@MainActor
private final class RefreshProbe {
    private(set) var count = 0
    private var waiters: [(target: Int, expectation: XCTestExpectation)] = []

    func expectation(forCount target: Int) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "refresh count reached \(target)")
        if count >= target {
            expectation.fulfill()
        } else {
            waiters.append((target, expectation))
        }
        return expectation
    }

    func refresh() {
        count += 1
        let ready = waiters.filter { $0.target <= count }
        waiters.removeAll { $0.target <= count }
        ready.forEach { $0.expectation.fulfill() }
    }
}

private func isBatteryEvent(_ event: EventBus.Event) -> Bool {
    if case .batteryPressureChanged = event { return true }
    return false
}

@MainActor
final class EventDrivenRefreshTests: XCTestCase {

    func testRefreshesOnceAfterRegistrationThenOnlyOnRelevantEvents() async {
        let bus = EventBus()
        let probe = RefreshProbe()
        let task = EventDrivenRefresh.start(
            eventBus: bus,
            where: { isBatteryEvent($0) },
            refresh: { [probe] in probe.refresh() }
        )

        await fulfillment(of: [probe.expectation(forCount: 1)], timeout: 2.0)
        XCTAssertEqual(probe.count, 1, "Exactly one catch-up refresh after registration")

        for index in 0..<40 {
            await bus.publish(.custom(name: "noise", payload: ["index": "\(index)"]))
        }
        await bus.publish(.batteryPressureChanged(level: 0.5, isLowPower: false))

        await fulfillment(of: [probe.expectation(forCount: 2)], timeout: 2.0)
        XCTAssertEqual(probe.count, 2, "Irrelevant events must not trigger refresh")

        task.cancel()
        await task.value
    }

    func testCancellationStopsRefresh() async {
        let bus = EventBus()
        let probe = RefreshProbe()
        let task = EventDrivenRefresh.start(
            eventBus: bus,
            where: { isBatteryEvent($0) },
            refresh: { [probe] in probe.refresh() }
        )

        await fulfillment(of: [probe.expectation(forCount: 1)], timeout: 2.0)
        task.cancel()
        await task.value

        await bus.publish(.batteryPressureChanged(level: 0.2, isLowPower: true))
        XCTAssertEqual(probe.count, 1, "Cancelled refresh task must not refresh again")
    }

    func testFallbackTimerRefreshesWithoutEvents() async {
        let bus = EventBus()
        let probe = RefreshProbe()
        let task = EventDrivenRefresh.start(
            eventBus: bus,
            fallbackInterval: .milliseconds(20),
            where: { _ in false },
            refresh: { [probe] in probe.refresh() }
        )

        await fulfillment(of: [probe.expectation(forCount: 3)], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(probe.count, 3)

        task.cancel()
        await task.value
    }

    func testRefreshTaskDoesNotRetainOwner() async {
        let bus = EventBus()
        var owner: RefreshProbe? = RefreshProbe()
        weak var weakOwner = owner
        let firstRefresh = XCTestExpectation(description: "first refresh")

        let task = EventDrivenRefresh.start(
            eventBus: bus,
            where: { isBatteryEvent($0) },
            refresh: { [weak owner] in
                owner?.refresh()
                firstRefresh.fulfill()
            }
        )
        await fulfillment(of: [firstRefresh], timeout: 2.0)

        owner = nil
        XCTAssertNil(weakOwner, "Live refresh must capture its owner weakly")

        task.cancel()
        await task.value
    }
}
