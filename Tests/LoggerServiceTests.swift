import XCTest
import os.log
@testable import Core

final class LoggerServiceTests: XCTestCase {
    func testLoggerServiceDefaultLogging() {
        let logger = LoggerService()
        logger.debug("Test debug message")
        logger.info("Test info message")
        logger.error("Test error message")
    }

    func testLoggerServiceCustomCategoryAndPrivacy() {
        let logger = LoggerService()
        logger.debug("Public debug message", category: logger.nexus, isPrivate: false)
        logger.info("Private info message", category: logger.ai, isPrivate: true)
        logger.error("Custom error message", category: logger.memory)
    }

    func testQuicksilverLoggerLogging() {
        QuicksilverLogger.debug("Test debug message")
        QuicksilverLogger.info("Test info message", category: QuicksilverLogger.nexus, isPrivate: false)
        QuicksilverLogger.error("Test error message", category: QuicksilverLogger.ui, isPrivate: true)
    }

    func testLoggerServiceRedaction() {
        XCTAssertEqual(LoggerService.redact(nil), "<empty>")
        XCTAssertEqual(LoggerService.redact(""), "<empty>")

        // Keys starting with xai- or sk- or containing "key" or >20 chars
        XCTAssertEqual(LoggerService.redact("sk-12345678901234567890"), "<redacted len=23>")
        XCTAssertEqual(LoggerService.redact("xai-98765432109876543210"), "<redacted len=24>")
        XCTAssertEqual(LoggerService.redact("mySecretKey"), "<redacted len=11>")
        XCTAssertEqual(LoggerService.redact("1234567890123456789012"), "<redacted len=22>")

        // Short non-secret strings
        XCTAssertEqual(LoggerService.redact("123", maxVisible: 4), "***")
        XCTAssertEqual(LoggerService.redact("12345678", maxVisible: 4), "1234…<redacted>")
    }
}
