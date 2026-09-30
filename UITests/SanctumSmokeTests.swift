import XCTest

final class SanctumSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uitest"]
        app.launch()
    }

    func testPrimarySanctumDestinationsOpenAndDismiss() throws {
        let destinations = [
            "The Workshop",
            "The Planetarium",
            "The Archive",
            "The Codex",
            "Diagnostics"
        ]

        for destination in destinations {
            let portal = app.buttons[destination]
            XCTAssertTrue(portal.waitForExistence(timeout: 5), "Missing portal: \(destination)")
            portal.tap()

            let done = app.buttons["Done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5), "Realm did not open: \(destination)")
            done.tap()
            XCTAssertTrue(portal.waitForExistence(timeout: 5), "Sanctum did not return after: \(destination)")
        }

        let invoke = app.buttons["Speak with Quicksilver"].firstMatch
        XCTAssertTrue(invoke.waitForExistence(timeout: 5))
        invoke.tap()
        XCTAssertTrue(app.navigationBars["Ask"].waitForExistence(timeout: 5))
        app.swipeDown()
    }

    func testSanctumAccessibilityAudit() throws {
        XCTAssertTrue(app.buttons["The Workshop"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit { issue in
            print(
                "AUDIT compact=\(issue.compactDescription) "
                    + "detail=\(issue.detailedDescription)"
            )
            return false
        }
    }
}
