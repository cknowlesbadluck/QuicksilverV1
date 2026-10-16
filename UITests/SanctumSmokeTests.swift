import XCTest

/// Simulator transport failures XCUITest records from `launch()` / `terminate()`
/// on shared CI runners (seen on main 2026-10-04). App defects do not produce
/// these messages; a crash or hang on launch still fails the single retry.
private let simulatorLaunchFlakeMarkers = [
    "Failed to get launch progress",
    "Timed out while requesting launch progress",
    "Failed to get background assertion",
    "Failed to terminate"
]

/// `performAccessibilityAudit` throws this when the audit itself times out.
/// It is not an accessibility finding: real findings reach the issue handler.
private let accessibilityAuditErrorDomain = "com.apple.xcode.xctest.accessibilityAudit"
private let accessibilityAuditTimedOutCode = -56

final class SanctumSmokeTests: XCTestCase {
    private static let launchTimeout: TimeInterval = 30
    private static let auditAttempts = 3
    private static let auditSettleInterval: TimeInterval = 5

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // `-uitest` freezes Sanctum decorative TimelineViews in-app;
        // otherwise performAccessibilityAudit can hang (~167s timeout).
        app.launchArguments = ["-uitest"]
        // Xcode 26 launch() terminates the previous process first. After
        // testPrimarySanctumDestinationsOpenAndDismiss passed (87s), the next
        // launch failed with "Failed to terminate com.quicksilver.app:0" and
        // the job exited 65. The destinations themselves were fine.
        // Reuse the running process. The destination test returns to Sanctum.
        // CI UI Smoke is an isolated job, so the first contact is always launch()
        // with `-uitest` (launchArguments only apply to launch, not activate).
        if app.state == .notRunning {
            launchRetryingSimulatorFlakeOnce()
        } else {
            app.activate()
            returnToSanctumIfNeeded()
        }
    }

    override func tearDownWithError() throws {
        // Do not terminate here. That is the race the next launch loses.
        app = nil
    }

    func testPrimarySanctumDestinationsOpenAndDismiss() throws {
        let destinations = [
            "The Workshop",
            "The Planetarium",
            "The Archive",
            "The Codex",
            "Diagnostics"
        ]

        returnToSanctumIfNeeded()

        for destination in destinations {
            let portal = app.buttons[destination]
            XCTAssertTrue(portal.waitForExistence(timeout: 8), "Missing portal: \(destination)")
            let done = openRealm(through: portal, named: destination)
            done.tap()
            XCTAssertTrue(portal.waitForExistence(timeout: 8), "Sanctum did not return after: \(destination)")
        }

        let invoke = app.buttons["Speak with Quicksilver"].firstMatch
        XCTAssertTrue(invoke.waitForExistence(timeout: 8))
        invoke.tap()
        XCTAssertTrue(app.navigationBars["Ask"].waitForExistence(timeout: 8))
        dismissAsk()
        XCTAssertFalse(app.navigationBars["Ask"].exists, "Ask sheet did not dismiss")
        XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 8))
    }

    func testSanctumAccessibilityAudit() throws {
        returnToSanctumIfNeeded()
        XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 8))
        // Sanctum portals and Speak with Quicksilver must be idle before audit.
        // Decorative motion is frozen via -uitest in AmbientLayer/core/Sanctum.
        // Audit a settled, complete screen: past failures were state-dependent
        // ("The core is awake", "Eternal", "·") because those labels were sometimes
        // mid-transition or not yet on screen. Waiting makes them always audited.
        waitForSettledSanctum()
        try performAccessibilityAuditRetryingTimeouts()
    }

    /// Waits until the presence title exists and the key labels stop moving.
    /// This never skips an element; it only makes sure the audit sees the final layout.
    private func waitForSettledSanctum() {
        // A sheet (Ask) or realm cover still animating away dims the Sanctum behind it; the
        // audit then fails contrast on whichever bottom label the dimming covers (Eternal,
        // Workshop). Wait until both are fully gone.
        waitUntilGone(app.navigationBars["Ask"])
        waitUntilGone(app.buttons["Done"])
        let presence = app.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["The core is awake", "The core rests"])
        ).firstMatch
        XCTAssertTrue(presence.waitForExistence(timeout: 8), "Presence title never appeared before audit")
        XCTAssertTrue(app.staticTexts["Eternal"].waitForExistence(timeout: 8), "Eternal subtitle never appeared before audit")
        waitForStableFrame(presence)
        waitForStableFrame(app.buttons["The Workshop"])
    }

    /// Waits until the element is gone or no longer hittable (off screen), then lets the dim fade.
    private func waitUntilGone(_ element: XCUIElement, timeout: TimeInterval = 10) {
        let deadline = Date().addingTimeInterval(timeout)
        while element.exists && element.isHittable && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertFalse(element.exists && element.isHittable, "Still on screen before audit: \(element)")
        Thread.sleep(forTimeInterval: 1) // dismissal animation's dimming fades after the element leaves
    }

    /// Polls an element's frame until it is unchanged for three consecutive 0.25s samples (max ~6s).
    private func waitForStableFrame(_ element: XCUIElement) {
        var last = element.frame
        var stableSamples = 0
        for _ in 0..<24 where stableSamples < 3 {
            Thread.sleep(forTimeInterval: 0.25)
            let current = element.frame
            stableSamples = current == last ? stableSamples + 1 : 0
            last = current
        }
    }

    /// Retries only the audit's own "failed to complete in time" error.
    /// Every accessibility issue the audit reports still fails the test.
    private func performAccessibilityAuditRetryingTimeouts() throws {
        for attempt in 1...Self.auditAttempts {
            do {
                try app.performAccessibilityAudit { issue in
                    // Element details identify intermittent offenders (e.g. "Hit area is too small"
                    // on an unlabeled SwiftUI.AccessibilityNode) without hiding the failure.
                    let element = issue.element
                    print(
                        "AUDIT compact=\(issue.compactDescription) "
                            + "detail=\(issue.detailedDescription) "
                            + "element=\(element?.identifier ?? "-")|\(element?.label ?? "-")|"
                            + "\(element.map { "\($0.elementType.rawValue)" } ?? "-")|"
                            + "frame=\(element.map { "\($0.frame)" } ?? "-")"
                    )
                    return false
                }
                return
            } catch {
                let nsError = error as NSError
                let timedOut = nsError.domain == accessibilityAuditErrorDomain
                    && nsError.code == accessibilityAuditTimedOutCode
                guard timedOut, attempt < Self.auditAttempts else { throw error }
                print("AUDIT attempt \(attempt) timed out; settling before retry")
                Thread.sleep(forTimeInterval: Self.auditSettleInterval)
                XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 8))
            }
        }
    }

    /// Taps a portal and returns the realm's Done button. A busy simulator can
    /// drop the first tap after a cold launch (PR #225 run 37238895244), so tap
    /// once more if the realm hasn't opened and the portal is still on screen.
    private func openRealm(through portal: XCUIElement, named destination: String) -> XCUIElement {
        let done = app.buttons["Done"]
        portal.tap()
        if !done.waitForExistence(timeout: 8) && portal.isHittable {
            print("PORTAL \(destination) did not open on first tap; tapping again")
            portal.tap()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 8), "Realm did not open: \(destination)")
        return done
    }

    /// Launches once; if the simulator drops the launch handshake, terminates
    /// and launches one more time. The retry's failures are recorded normally.
    private func launchRetryingSimulatorFlakeOnce() {
        let options = XCTExpectedFailure.Options()
        options.isStrict = false
        options.issueMatcher = { issue in
            simulatorLaunchFlakeMarkers.contains { issue.compactDescription.contains($0) }
        }

        continueAfterFailure = true
        XCTExpectFailure("Simulator launch handshake flake; relaunching once", options: options) {
            app.launch()
        }
        if app.wait(for: .runningForeground, timeout: Self.launchTimeout) {
            continueAfterFailure = false
            return
        }

        print("LAUNCH first attempt did not reach foreground; relaunching")
        XCTExpectFailure("Simulator terminate flake before relaunch", options: options) {
            app.terminate()
        }
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: Self.launchTimeout),
            "App did not reach foreground after relaunch"
        )
    }

    // Known gap (PR #225): this center swipeDown() often leaves the Ask sheet
    // presented, so the audit mostly covers Ask. Truly dismissing it surfaces
    // Sanctum header findings (contrast, Dynamic Type) to fix in product code
    // before tightening this helper.
    /// The first swipe can only dismiss the keyboard (Ask focuses its field), leaving the
    /// sheet up over a Sanctum that still "exists" behind it. Swipe from the nav bar until gone.
    private func dismissAsk() {
        let bar = app.navigationBars["Ask"]
        for _ in 0..<4 where bar.exists {
            if app.keyboards.count > 0 { app.keyboards.firstMatch.swipeDown() }
            bar.swipeDown(velocity: .fast)
            _ = bar.waitForNonExistence(timeout: 3)
        }
    }

    private func returnToSanctumIfNeeded() {
        dismissAsk()
        if app.buttons["Done"].exists && !app.buttons["The Workshop"].exists {
            app.buttons["Done"].tap()
        }
    }
}
