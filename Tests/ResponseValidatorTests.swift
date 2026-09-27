import XCTest
@testable import Core
@testable import ServicesAI

final class ResponseValidatorTests: XCTestCase {

    func testRejectsEmpty() {
        let response = AIResponse(requestID: UUID(), content: "   ")
        if case .reject = ResponseValidator.validate(response) {
            // expected
        } else {
            XCTFail("Expected reject")
        }
    }

    func testAcceptsNormal() {
        let response = AIResponse(requestID: UUID(), content: "Forge ready.")
        if case .accept(let accepted) = ResponseValidator.validate(response) {
            XCTAssertEqual(accepted.content, "Forge ready.")
        } else {
            XCTFail("Expected accept")
        }
    }
}
