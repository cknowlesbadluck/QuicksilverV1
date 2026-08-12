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

        XCTAssertEqual(policy.primary.providerID, "primary")
        XCTAssertEqual(policy.secondary.providerID, "secondary")
        XCTAssertEqual(policy.fallback.providerID, "fallback")
        XCTAssertEqual(policy.orderedRoutes.count, 3)
    }

    func testCapabilityBrokerDeniesMissingRelic() async {
        let broker = CapabilityBroker()
        do {
            _ = try await broker.invoke(
                relicID: RelicID("missing"),
                request: RelicRequest(action: "ping")
            )
            XCTFail("Expected relicUnavailable")
        } catch let error as CapabilityBrokerError {
            XCTAssertEqual(error, .relicUnavailable("missing"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCapabilityBrokerDeniesMissingGlyph() async {
        let broker = CapabilityBroker()
        do {
            try await broker.connect(glyphID: GlyphID("missing-glyph"))
            XCTFail("Expected glyphUnavailable")
        } catch let error as CapabilityBrokerError {
            XCTAssertEqual(error, .glyphUnavailable("missing-glyph"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAllowLocalLowRiskPolicyAllowsLowLocal() async {
        let policy = AllowLocalLowRiskPolicy()
        let manifest = CapabilityManifest(
            name: "local-tool",
            description: "test",
            transmissionPolicy: .localOnly,
            risk: .low
        )
        let result = await policy.authorize(manifest)
        XCTAssertEqual(result, .allowed)
    }

    func testAllowLocalLowRiskPolicyRequiresApprovalForHigherRisk() async {
        let policy = AllowLocalLowRiskPolicy()
        let manifest = CapabilityManifest(
            name: "risky-tool",
            description: "test",
            transmissionPolicy: .localOnly,
            risk: .moderate
        )
        let result = await policy.authorize(manifest)
        XCTAssertEqual(result, .requiresUserApproval)
    }

    func testAllowLocalLowRiskPolicyRequiresApprovalForNonLocal() async {
        let policy = AllowLocalLowRiskPolicy()
        let manifest = CapabilityManifest(
            name: "cloud-tool",
            description: "test",
            transmissionPolicy: .providerSafe,
            risk: .low
        )
        let result = await policy.authorize(manifest)
        XCTAssertEqual(result, .requiresUserApproval)
    }

    func testProviderRouterFallsBackWhenPrimaryUnavailable() async throws {
        final class MockProvider: AIProvider, @unchecked Sendable {
            let id: String
            let displayName: String
            let isAvailable: Bool
            let shouldFail: Bool

            init(id: String, isAvailable: Bool = true, shouldFail: Bool = false) {
                self.id = id
                self.displayName = id
                self.isAvailable = isAvailable
                self.shouldFail = shouldFail
            }

            func complete(_ request: AIRequest) async throws -> AIResponse {
                if shouldFail {
                    throw AIProviderFailure.transient
                }
                return AIResponse(requestID: request.id, content: "from-\(id)")
            }
        }

        let primary = MockProvider(id: "primary", isAvailable: false)
        let secondary = MockProvider(id: "secondary", isAvailable: true)
        let fallback = MockProvider(id: "fallback", isAvailable: true)

        let router = MercuryProviderRouter(
            policy: MercuryProviderPolicy(),
            providers: [primary, secondary, fallback]
        )

        let response = try await router.complete(AIRequest(prompt: "test"))
        XCTAssertEqual(response.content, "from-secondary")
    }

    func testProviderRouterUsesFallbackWhenEarlierFail() async throws {
        final class MockProvider: AIProvider, @unchecked Sendable {
            let id: String
            let displayName: String
            let isAvailable: Bool
            let shouldFail: Bool

            init(id: String, isAvailable: Bool = true, shouldFail: Bool = false) {
                self.id = id
                self.displayName = id
                self.isAvailable = isAvailable
                self.shouldFail = shouldFail
            }

            func complete(_ request: AIRequest) async throws -> AIResponse {
                if shouldFail {
                    throw AIProviderFailure.rateLimited
                }
                return AIResponse(requestID: request.id, content: "from-\(id)")
            }
        }

        let primary = MockProvider(id: "primary", shouldFail: true)
        let secondary = MockProvider(id: "secondary", shouldFail: true)
        let fallback = MockProvider(id: "fallback")

        let router = MercuryProviderRouter(
            policy: MercuryProviderPolicy(),
            providers: [primary, secondary, fallback]
        )

        let response = try await router.complete(AIRequest(prompt: "test"))
        XCTAssertEqual(response.content, "from-fallback")
    }

    func testProviderRouterThrowsWhenAllUnavailable() async {
        let router = MercuryProviderRouter(policy: MercuryProviderPolicy(), providers: [])
        do {
            _ = try await router.complete(AIRequest(prompt: "test"))
            XCTFail("Expected unavailable")
        } catch let error as AIProviderFailure {
            XCTAssertEqual(error, .unavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
