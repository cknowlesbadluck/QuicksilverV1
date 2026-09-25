import XCTest
@testable import Core

@MainActor
final class EventBusTests: XCTestCase {

    func testSubscribeAndPublishSingleEvent() async {
        let bus = EventBus()
        let expectation = XCTestExpectation(description: "Handler received personaDidChange event")

        nonisolated(unsafe) var receivedPersonaID: String?
        _ = await bus.subscribe { event in
            if case .personaDidChange(let personaID) = event {
                receivedPersonaID = personaID
                expectation.fulfill()
            }
        }

        await bus.publish(.personaDidChange(personaID: "forge"))

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedPersonaID, "forge")
    }

    func testMultipleSubscribers() async {
        let bus = EventBus()
        let expectation1 = XCTestExpectation(description: "Subscriber 1 received event")
        let expectation2 = XCTestExpectation(description: "Subscriber 2 received event")

        _ = await bus.subscribe { event in
            if case .memoryDidUpdate(let itemID) = event, itemID == "item123" {
                expectation1.fulfill()
            }
        }

        _ = await bus.subscribe { event in
            if case .memoryDidUpdate(let itemID) = event, itemID == "item123" {
                expectation2.fulfill()
            }
        }

        await bus.publish(.memoryDidUpdate(itemID: "item123"))

        await fulfillment(of: [expectation1, expectation2], timeout: 2.0)
    }

    func testUnsubscribe() async {
        let bus = EventBus()
        nonisolated(unsafe) var receivedCount = 0

        let subscriptionID = await bus.subscribe { _ in
            receivedCount += 1
        }

        await bus.publish(.featureFlagDidChange(key: "experimentalEventBus", enabled: true))
        XCTAssertEqual(receivedCount, 1)

        await bus.unsubscribe(subscriptionID)

        await bus.publish(.featureFlagDidChange(key: "experimentalEventBus", enabled: false))
        XCTAssertEqual(receivedCount, 1, "Handler should not be called after unsubscribing")
    }

    func testUnsubscribeOneOfMultiple() async {
        let bus = EventBus()
        nonisolated(unsafe) var count1 = 0
        nonisolated(unsafe) var count2 = 0

        let id1 = await bus.subscribe { _ in count1 += 1 }
        let id2 = await bus.subscribe { _ in count2 += 1 }

        await bus.publish(.aiRequestStarted(requestID: "req-1"))
        XCTAssertEqual(count1, 1)
        XCTAssertEqual(count2, 1)

        await bus.unsubscribe(id1)

        await bus.publish(.aiRequestCompleted(requestID: "req-1"))
        XCTAssertEqual(count1, 1, "Subscriber 1 should no longer receive events")
        XCTAssertEqual(count2, 2, "Subscriber 2 should continue receiving events")

        _ = id2
    }

    func testUnsubscribeInvalidUUIDDoesNotCrash() async {
        let bus = EventBus()
        let randomID = UUID()

        nonisolated(unsafe) var receivedCount = 0
        _ = await bus.subscribe { _ in receivedCount += 1 }

        await bus.unsubscribe(randomID)

        await bus.publish(.thermalPressureChanged(state: "nominal"))
        XCTAssertEqual(receivedCount, 1)
    }

    func testPublishAllEventVariants() async {
        let bus = EventBus()
        nonisolated(unsafe) var receivedEventsCount = 0

        _ = await bus.subscribe { _ in
            receivedEventsCount += 1
        }

        let eventsToPublish: [EventBus.Event] = [
            .personaDidChange(personaID: "quicksilver"),
            .memoryDidUpdate(itemID: "mem-42"),
            .featureFlagDidChange(key: "smartRouting", enabled: true),
            .aiRequestStarted(requestID: "req-100"),
            .aiRequestCompleted(requestID: "req-100"),
            .signalReceived(source: "location", value: "home", numericValue: 0.95),
            .focusDidChange(focusName: "Work"),
            .timeContextDidChange(period: .morning),
            .batteryPressureChanged(level: 0.85, isLowPower: false),
            .thermalPressureChanged(state: "fair"),
            .networkConditionChanged(isConnected: true, isConstrained: false),
            .custom(name: "customEvent", payload: ["key": "val"])
        ]

        for event in eventsToPublish {
            await bus.publish(event)
        }

        XCTAssertEqual(receivedEventsCount, eventsToPublish.count)
    }

    func testConcurrentPublishAndSubscribe() async {
        let bus = EventBus()

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<50 {
                group.addTask {
                    let id = await bus.subscribe { _ in }
                    await bus.publish(.custom(name: "test", payload: ["index": "\(index)"]))
                    await bus.unsubscribe(id)
                }
            }
        }
    }

    func testAsyncStreamReceivesPublishedEvents() async {
        let bus = EventBus()
        let stream = await bus.events()

        let expectation = XCTestExpectation(description: "Stream received battery event")
        nonisolated(unsafe) var receivedLevel: Double?

        let consumer = Task {
            for await event in stream {
                if case .batteryPressureChanged(let level, _) = event {
                    receivedLevel = level
                    expectation.fulfill()
                    break
                }
            }
        }

        // Give the continuation a moment to register
        try? await Task.sleep(for: .milliseconds(50))
        await bus.publish(.batteryPressureChanged(level: 0.42, isLowPower: false))

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedLevel, 0.42)
        consumer.cancel()
    }

    func testAsyncStreamCancellationStopsDelivery() async {
        let bus = EventBus()
        // `events()` registers the stream before returning, so no settle delay is needed.
        let stream = await bus.events()
        let firstReceived = XCTestExpectation(description: "Consumer received first event")

        nonisolated(unsafe) var count = 0
        let consumer = Task {
            for await _ in stream {
                count += 1
                firstReceived.fulfill()
            }
        }

        await bus.publish(.thermalPressureChanged(state: "nominal"))
        await fulfillment(of: [firstReceived], timeout: 2.0)
        XCTAssertEqual(count, 1)

        consumer.cancel()
        // Deterministic: wait until the consumer loop has actually exited.
        await consumer.value

        await bus.publish(.thermalPressureChanged(state: "fair"))
        XCTAssertEqual(count, 1, "Cancelled stream must not receive further events")
    }

    func testFilteredStreamIsNotStarvedByIrrelevantEvents() async {
        let bus = EventBus()
        let stream = await bus.events(bufferingNewest: 1) { event in
            if case .batteryPressureChanged = event { return true }
            return false
        }
        let unfiltered = await bus.events(bufferingNewest: 64)

        await bus.publish(.batteryPressureChanged(level: 0.3, isLowPower: false))
        for index in 0..<40 {
            await bus.publish(.custom(name: "noise", payload: ["index": "\(index)"]))
        }

        var firstFiltered: EventBus.Event?
        for await event in stream {
            firstFiltered = event
            break
        }
        guard case .batteryPressureChanged(let level, _) = firstFiltered else {
            return XCTFail("Filtered stream should retain the relevant event, got \(String(describing: firstFiltered))")
        }
        XCTAssertEqual(level, 0.3)

        // Other stream subscribers still see every event.
        var unfilteredCount = 0
        for await _ in unfiltered {
            unfilteredCount += 1
            if unfilteredCount == 41 { break }
        }
        XCTAssertEqual(unfilteredCount, 41)
    }

    func testCallbackAndStreamBothReceive() async {
        let bus = EventBus()
        let callbackExpectation = XCTestExpectation(description: "Callback received")
        let streamExpectation = XCTestExpectation(description: "Stream received")

        _ = await bus.subscribe { event in
            if case .networkConditionChanged = event {
                callbackExpectation.fulfill()
            }
        }

        let stream = await bus.events()
        let consumer = Task {
            for await event in stream {
                if case .networkConditionChanged = event {
                    streamExpectation.fulfill()
                    break
                }
            }
        }

        try? await Task.sleep(for: .milliseconds(50))
        await bus.publish(.networkConditionChanged(isConnected: true, isConstrained: false))

        await fulfillment(of: [callbackExpectation, streamExpectation], timeout: 2.0)
        consumer.cancel()
    }
}
