import XCTest

final class SanctumSmokeTests: XCTestCase {
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
        if app.state == .notRunning {
            app.launch()
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
            portal.tap()

            let done = app.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 8), "Realm did not open: \(destination)")
            done.tap()
            XCTAssertTrue(portal.waitForExistence(timeout: 8), "Sanctum did not return after: \(destination)")
        }

        let invoke = app.buttons["Speak with Quicksilver"].firstMatch
        XCTAssertTrue(invoke.waitForExistence(timeout: 8))
        invoke.tap()
        XCTAssertTrue(app.navigationBars["Ask"].waitForExistence(timeout: 8))
        app.swipeDown()
        XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 8))
    }

    func testSanctumAccessibilityAudit() throws {
        returnToSanctumIfNeeded()
        XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 8))
        // Sanctum portals and Speak with Quicksilver must be idle before audit.
        // Decorative motion is frozen via -uitest in AmbientLayer/core/Sanctum.
        try app.performAccessibilityAudit { issue in
            print(
                "AUDIT compact=\(issue.compactDescription) "
                    + "detail=\(issue.detailedDescription)"
            )
            return false
        }
    }

    private func returnToSanctumIfNeeded() {
        if app.navigationBars["Ask"].exists {
            app.swipeDown()
        }
        if app.buttons["Done"].exists && !app.buttons["The Workshop"].exists {
            app.buttons["Done"].tap()
        }
    }
}
