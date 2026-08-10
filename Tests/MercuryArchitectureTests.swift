import XCTest
@testable import Core

final class MercuryArchitectureTests: XCTestCase {
    func testDefaultIdentityIsQuicksilverCentric() {
        let identity = MercuryIdentity()

        XCTAssertEqual(identity.name, "Mercury")
        XCTAssertTrue(identity.baselineTraits.contains(.witty))
        XCTAssertTrue(identity.baselineTraits.contains(.loyal))
        XCTAssertTrue(identity.baselineTraits.contains(.challenging))
    }

    func testExpressionSupportsBlendedAspects() {
        let expression = MercuryExpression(
            quicksilver: 0.7,
            forge: 0.25,
            eternal: 0.05
        )

        XCTAssertEqual(expression.dominantAspect, .quicksilver)
    }

    func testExpressionClampsValues() {
        let expression = MercuryExpression(
            quicksilver: 2,
            forge: -1,
            eternal: 0.5
        )

        XCTAssertEqual(expression.quicksilver, 1)
        XCTAssertEqual(expression.forge, 0)
        XCTAssertEqual(expression.eternal, 0.5)
    }

    func testForgeEmergesFromCreativeTechnicalContext() {
        let expression = MercuryAspectResolver().resolve(
            .init(creativeIntensity: 1, technicalIntensity: 0.9)
        )

        XCTAssertGreaterThan(expression.forge, 0.9)
        XCTAssertGreaterThan(expression.curiosity, 0.8)
        XCTAssertGreaterThan(expression.creativity, 0.9)
    }

    func testEternalEmergesFromCodexAutomationContext() {
        let expression = MercuryAspectResolver().resolve(
            .init(codexRelevance: 1, automationRelevance: 0.9)
        )

        XCTAssertGreaterThan(expression.eternal, 0.9)
        XCTAssertGreaterThan(expression.authority, 0.7)
        XCTAssertGreaterThan(expression.precision, 0.9)
    }

    func testDefaultProviderPolicyHasPrimarySecondaryAndFallback() {
        let policy = MercuryProviderPolicy()

        XCTAssertEqual(policy.primary.providerID, "gemini")
        XCTAssertEqual(policy.secondary.providerID, "groq")
        XCTAssertEqual(policy.fallback.providerID, "openrouter-free")
        XCTAssertEqual(policy.orderedRoutes.count, 3)
    }
}
