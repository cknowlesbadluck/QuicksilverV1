import XCTest
@testable import Quicksilver

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(String(describing: DependencyContainer.self), "DependencyContainer")
    }
}
