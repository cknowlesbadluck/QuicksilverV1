import XCTest
import os.log
@testable import Core

final class LoggerServiceTests: XCTestCase {

    func testInitializationDefaultsAndCustomSubsystem() {
        let defaultService = LoggerService()
        XCTAssertNotNil(defaultService.general)
        XCTAssertNotNil(defaultService.nexus)
        XCTAssertNotNil(defaultService.persona)
        XCTAssertNotNil(defaultService.memory)
        XCTAssertNotNil(defaultService.ai)
        XCTAssertNotNil(defaultService.ui)

        let customService = LoggerService(subsystem: "com.test.subsystem")
        XCTAssertNotNil(customService.general)
        XCTAssertNotNil(customService.nexus)
        XCTAssertNotNil(customService.persona)
        XCTAssertNotNil(customService.memory)
        XCTAssertNotNil(customService.ai)
        XCTAssertNotNil(customService.ui)
    }

    func testLoggingMethods() {
        let service = LoggerService()

        // Verify default category usage
        service.debug("Debug message")
        service.info("Info message")
        service.error("Error message")

        // Verify custom category usage
        service.debug("Debug message", category: service.nexus)
        service.info("Info message", category: service.ai)
        service.error("Error message", category: service.memory)
    }

    func testRedactNilAndEmpty() {
        XCTAssertEqual(LoggerService.redact(nil), "<empty>")
        XCTAssertEqual(LoggerService.redact(""), "<empty>")
    }

    func testRedactLongStrings() {
        let longString = "123456789012345678901" // length 21
        XCTAssertEqual(LoggerService.redact(longString), "<redacted len=21>")
    }

    func testRedactKeyInValue() {
        XCTAssertEqual(LoggerService.redact("myKey"), "<redacted len=5>")
        XCTAssertEqual(LoggerService.redact("API_KEY_123"), "<redacted len=11>")
        XCTAssertEqual(LoggerService.redact("KEY"), "<redacted len=3>")
    }

    func testRedactPrefixes() {
        XCTAssertEqual(LoggerService.redact("sk-12345"), "<redacted len=8>")
        XCTAssertEqual(LoggerService.redact("xai-abc"), "<redacted len=7>")
    }

    func testRedactShortStringsWithinMaxVisible() {
        XCTAssertEqual(LoggerService.redact("a", maxVisible: 4), "*")
        XCTAssertEqual(LoggerService.redact("ab", maxVisible: 4), "**")
        XCTAssertEqual(LoggerService.redact("abc", maxVisible: 4), "***")
        XCTAssertEqual(LoggerService.redact("abcd", maxVisible: 4), "****")
    }

    func testRedactNormalStringsAboveMaxVisible() {
        XCTAssertEqual(LoggerService.redact("hello", maxVisible: 4), "hell…<redacted>")
        XCTAssertEqual(LoggerService.redact("secret-val", maxVisible: 3), "sec…<redacted>")
        XCTAssertEqual(LoggerService.redact("12345678901234567890", maxVisible: 4), "1234…<redacted>") // length 20
    }
}
