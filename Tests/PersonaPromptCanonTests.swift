import XCTest
@testable import Personas

/// P-T2: aspect prompt canon — file↔fallback parity, forbidden/required strings, unbreakable fixture.
final class PersonaPromptCanonTests: XCTestCase {

    private var personasDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Personas", isDirectory: true)
    }

    private var unbreakableFixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/unbreakable.txt")
    }

    private let aspectNames = ["quicksilver", "forge", "eternal"]
    private let allPromptNames = ["core", "core-compact", "quicksilver", "forge", "eternal"]

    private let forbidden: [String] = [
        "You are Forge",
        "You are Eternal",
        "You are Quicksilver",
        "Loki",
        "Asgard",
        "Marvel",
        "Mock mediocrity",
        "never the person",
        "never mock him",
        "never mock Christopher"
    ]

    // MARK: - Parity

    func testAspectFilesEqualFallbacks() throws {
        let pairs: [(String, String)] = [
            ("quicksilver", PersonaConfiguration.quicksilverPromptFallback),
            ("forge", PersonaConfiguration.forgePromptFallback),
            ("eternal", PersonaConfiguration.eternalPromptFallback)
        ]
        for (name, fallback) in pairs {
            let file = try loadPersonaFile(name)
            let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(file, trimmedFallback, "\(name).txt must equal its PersonaConfiguration fallback")
        }
    }

    func testCoreFilesEqualEmbeddedFallbacks() throws {
        let core = try loadPersonaFile("core")
        let compact = try loadPersonaFile("core-compact")
        XCTAssertEqual(
            core,
            PromptManager.embeddedCoreFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        XCTAssertEqual(
            compact,
            PromptManager.embeddedCoreCompactFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func testResolvedSystemPromptsMatchFallbacksInSPM() {
        // Bundle.main has no Personas resources under SPM; systemPrompt must be the fallback.
        XCTAssertEqual(
            PersonaConfiguration.quicksilver.systemPrompt,
            PersonaConfiguration.quicksilverPromptFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        XCTAssertEqual(
            PersonaConfiguration.forge.systemPrompt,
            PersonaConfiguration.forgePromptFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        XCTAssertEqual(
            PersonaConfiguration.eternal.systemPrompt,
            PersonaConfiguration.eternalPromptFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Forbidden / owner name

    func testNoForbiddenStringsInBundledOrFallbackPrompts() throws {
        var corpus: [(String, String)] = []
        for name in allPromptNames {
            corpus.append((name + ".txt", try loadPersonaFile(name)))
        }
        corpus.append(("quicksilverFallback", PersonaConfiguration.quicksilverPromptFallback))
        corpus.append(("forgeFallback", PersonaConfiguration.forgePromptFallback))
        corpus.append(("eternalFallback", PersonaConfiguration.eternalPromptFallback))
        corpus.append(("coreFallback", PromptManager.embeddedCoreFallback))
        corpus.append(("coreCompactFallback", PromptManager.embeddedCoreCompactFallback))

        for (label, text) in corpus {
            for needle in forbidden {
                XCTAssertFalse(text.contains(needle), "\(label) must not contain \(needle)")
            }
        }
    }

    func testNoLiteralOwnerNameInPromptFiles() throws {
        for name in allPromptNames {
            let text = try loadPersonaFile(name)
            XCTAssertFalse(text.contains("Christopher"), "\(name).txt must use {{owner}} only")
            if name == "core" || name == "core-compact" || name == "quicksilver" || name == "eternal" {
                XCTAssertTrue(text.contains("{{owner}}"), "\(name).txt should mention {{owner}}")
            }
        }
    }

    // MARK: - Required strings

    func testCoreRequiredStrings() throws {
        let core = try loadPersonaFile("core")
        XCTAssertTrue(core.contains("on {{owner}}'s side"))
        XCTAssertTrue(core.contains("never undermine, deceive or work against him"))
        XCTAssertTrue(core.contains("family"))
        XCTAssertTrue(core.contains("money"))
    }

    func testCoreCompactRequiredStrings() throws {
        let compact = try loadPersonaFile("core-compact")
        XCTAssertTrue(compact.contains("on his side"))
        XCTAssertTrue(compact.contains("Refuse harmful requests"))
        XCTAssertTrue(compact.contains("family"))
        XCTAssertTrue(compact.contains("money"))
    }

    func testAspectRequiredStrings() throws {
        for name in aspectNames {
            let text = try loadPersonaFile(name)
            XCTAssertTrue(text.contains("Mercury"), name)
            XCTAssertTrue(text.contains("Never lie"), name)
        }
        let forge = try loadPersonaFile("forge")
        XCTAssertTrue(forge.contains("recommendation"))
        let eternal = try loadPersonaFile("eternal")
        XCTAssertTrue(eternal.contains("Never invent or embellish"))
    }

    // MARK: - Unbreakable fixture

    func testUnbreakableLinesMatchFixtureByteForByte() throws {
        let fixture = try String(contentsOf: unbreakableFixtureURL, encoding: .utf8)
        let core = try String(
            contentsOf: personasDir.appendingPathComponent("core.txt"),
            encoding: .utf8
        )
        guard let range = core.range(of: "Unbreakable:\n") else {
            XCTFail("core.txt missing Unbreakable: header")
            return
        }
        let unbreakableBlock = String(core[range.upperBound...])
        XCTAssertEqual(
            unbreakableBlock,
            fixture,
            "core.txt Unbreakable bullets must equal Tests/Fixtures/unbreakable.txt byte for byte"
        )
        // Embedded fallback must carry the same lines.
        let fallback = PromptManager.embeddedCoreFallback
        XCTAssertTrue(fallback.contains(fixture.trimmingCharacters(in: .whitespacesAndNewlines)))
    }

    // MARK: - Traits

    func testControlledChaosTraits() {
        XCTAssertEqual(PersonaConfiguration.quicksilver.traits["tone"], "snarky")
        XCTAssertEqual(PersonaConfiguration.forge.traits["tone"], "erratic")
        XCTAssertEqual(PersonaConfiguration.forge.traits["style"], "precision")
        XCTAssertEqual(PersonaConfiguration.eternal.traits["tone"], "aloof")
        XCTAssertEqual(PersonaConfiguration.eternal.traits["style"], "ancient")
    }

    // MARK: - Helpers

    private func loadPersonaFile(_ name: String) throws -> String {
        let url = personasDir.appendingPathComponent("\(name).txt")
        let raw = try String(contentsOf: url, encoding: .utf8)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
