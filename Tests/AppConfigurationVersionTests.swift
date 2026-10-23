import XCTest
@testable import Core

final class AppConfigurationVersionTests: XCTestCase {
    func testReadsVersionAndBuildFromInfoDictionary() {
        let config = AppConfiguration(infoDictionary: [
            "CFBundleShortVersionString": "1.4.2",
            "CFBundleVersion": "42"
        ])
        XCTAssertEqual(config.version, "1.4.2")
        XCTAssertEqual(config.build, "42")
        XCTAssertEqual(config.fullVersionString, "1.4.2 (42)")
    }

    func testMissingDictionaryFallsBack() {
        let config = AppConfiguration(infoDictionary: nil)
        XCTAssertEqual(config.version, AppConfiguration.fallbackVersion)
        XCTAssertEqual(config.build, AppConfiguration.fallbackBuild)
    }

    func testBlankOrWrongTypeValuesFallBack() {
        let config = AppConfiguration(infoDictionary: [
            "CFBundleShortVersionString": "   ",
            "CFBundleVersion": 7
        ])
        XCTAssertEqual(config.version, AppConfiguration.fallbackVersion)
        XCTAssertEqual(config.build, AppConfiguration.fallbackBuild)
    }

    func testValuesAreTrimmed() {
        let config = AppConfiguration(infoDictionary: ["CFBundleShortVersionString": " 0.3.0\n"])
        XCTAssertEqual(config.version, "0.3.0")
        XCTAssertEqual(config.build, AppConfiguration.fallbackBuild)
    }

    func testDefaultInitMatchesFallbacks() {
        XCTAssertEqual(AppConfiguration().fullVersionString,
                       "\(AppConfiguration.fallbackVersion) (\(AppConfiguration.fallbackBuild))")
    }
}
