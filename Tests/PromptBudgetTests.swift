import XCTest
@testable import Personas

/// P-T3: prompt token-budget guard — named caps, chars÷4 estimator, SPM measurement table.
final class PromptBudgetTests: XCTestCase {

    private struct Measurement {
        let name: String
        let words: Int
        let tokens: Int
    }

    private var personasDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Personas", isDirectory: true)
    }

    private let aspectNames = ["quicksilver", "forge", "eternal"]
    private let allNames = ["core", "core-compact", "quicksilver", "forge", "eternal"]

    // MARK: - Estimator

    func testEstimatedTokensIsCharsDividedByFour() {
        XCTAssertEqual(PromptBudget.estimatedTokens(""), 0)
        XCTAssertEqual(PromptBudget.estimatedTokens("abcd"), 1)
        XCTAssertEqual(PromptBudget.estimatedTokens("abcde"), 1)
        XCTAssertEqual(PromptBudget.estimatedTokens(String(repeating: "x", count: 419)), 104)
    }

    func testLongestOwnerIsChristopher() {
        XCTAssertEqual(PromptBudget.longestOwnerSubstitution, "Christopher")
        XCTAssertGreaterThanOrEqual(
            PromptBudget.longestOwnerSubstitution.count,
            PromptComposer.cloudOwnerLabel.count
        )
    }

    // MARK: - File budgets

    func testAspectWordAndTokenCaps() throws {
        for name in aspectNames {
            let text = try prepared(name)
            let words = PromptBudget.wordCount(text)
            let tokens = PromptBudget.estimatedTokens(text)
            XCTAssertLessThanOrEqual(
                words,
                PromptBudget.aspectMaxWords,
                "\(name).txt words \(words) > \(PromptBudget.aspectMaxWords)"
            )
            XCTAssertLessThanOrEqual(
                tokens,
                PromptBudget.aspectMaxTokens,
                "\(name).txt tokens \(tokens) > \(PromptBudget.aspectMaxTokens)"
            )
        }
    }

    func testCoreAndCompactTokenCaps() throws {
        let core = try prepared("core")
        let compact = try prepared("core-compact")
        XCTAssertLessThanOrEqual(
            PromptBudget.estimatedTokens(core),
            PromptBudget.coreMaxTokens
        )
        XCTAssertLessThanOrEqual(
            PromptBudget.estimatedTokens(compact),
            PromptBudget.compactMaxTokens
        )
    }

    func testDraftMeasurementsMatchReferenceTable() throws {
        // docs/mercury-prompts/README.md: 418 / 159 / 229 / 256 / 240
        let expected: [(String, Int)] = [
            ("core", 418),
            ("core-compact", 159),
            ("quicksilver", 229),
            ("forge", 256),
            ("eternal", 240)
        ]
        for (name, tokens) in expected {
            let measured = PromptBudget.estimatedTokens(try prepared(name))
            XCTAssertEqual(measured, tokens, "\(name) draft measure drifted")
        }
    }

    // MARK: - Composed budgets

    func testFullComposedBudgetWithMaxBias() throws {
        let core = try prepared("core")
        let maxBias = PromptBudget.maximumPromptBias()
        XCTAssertFalse(maxBias.isEmpty)
        XCTAssertGreaterThanOrEqual(PromptBudget.biasClauses(from: maxBias).count, 6)

        for name in aspectNames {
            let aspect = try prepared(name)
            let head = PromptBudget.composedHead(core: core, aspect: aspect, bias: maxBias)
            let tokens = PromptBudget.estimatedTokens(head)
            XCTAssertLessThanOrEqual(
                tokens,
                PromptBudget.fullComposedMaxTokens,
                "core+\(name)+maxBias = \(tokens) > \(PromptBudget.fullComposedMaxTokens)"
            )
        }
    }

    func testCompactComposedBudgets() throws {
        let compact = try prepared("core-compact")
        let compactBias = PromptBudget.compactModeBias()
        let clauseCount = PromptBudget.biasClauses(from: compactBias).count
        XCTAssertLessThanOrEqual(clauseCount, PromptBudget.compactBiasClauseLimit)
        XCTAssertGreaterThan(clauseCount, 0)

        for name in aspectNames {
            let aspect = try prepared(name)
            let withoutBias = PromptBudget.composedHead(core: compact, aspect: aspect)
            let withBias = PromptBudget.composedHead(
                core: compact,
                aspect: aspect,
                bias: compactBias
            )
            XCTAssertLessThanOrEqual(
                PromptBudget.estimatedTokens(withoutBias),
                PromptBudget.compactComposedMaxTokens,
                "compact+\(name)"
            )
            XCTAssertLessThanOrEqual(
                PromptBudget.estimatedTokens(withBias),
                PromptBudget.compactComposedWithBiasMaxTokens,
                "compact+\(name)+≤2 bias clauses"
            )
        }
    }

    // MARK: - SPM log table

    func testPrintMeasurementTable() throws {
        var rows: [Measurement] = []
        for name in allNames {
            let text = try prepared(name)
            rows.append(
                Measurement(
                    name: name,
                    words: PromptBudget.wordCount(text),
                    tokens: PromptBudget.estimatedTokens(text)
                )
            )
        }

        var table = "\nP-T3 PromptBudget measurement table"
        table += " ({{owner}}→\(PromptBudget.longestOwnerSubstitution)):\n"
        table += pad("file", 14) + pad("words", 8) + pad("tokens", 8) + "\n"
        table += String(repeating: "-", count: 30) + "\n"
        for row in rows {
            table += pad(row.name, 14)
            table += pad(String(row.words), 8)
            table += pad(String(row.tokens), 8)
            table += "\n"
        }

        let maxBias = PromptBudget.maximumPromptBias()
        let compactBias = PromptBudget.compactModeBias()
        table += "\nComposed (est. tokens):\n"
        for name in aspectNames {
            let aspect = try prepared(name)
            let core = try prepared("core")
            let compact = try prepared("core-compact")
            let full = PromptBudget.estimatedTokens(
                PromptBudget.composedHead(core: core, aspect: aspect, bias: maxBias)
            )
            let compactAlone = PromptBudget.estimatedTokens(
                PromptBudget.composedHead(core: compact, aspect: aspect)
            )
            let compactPlus = PromptBudget.estimatedTokens(
                PromptBudget.composedHead(core: compact, aspect: aspect, bias: compactBias)
            )
            table += "  \(name): full+maxBias=\(full)"
            table += "  compact=\(compactAlone)"
            table += "  compact+2bias=\(compactPlus)\n"
        }
        print(table)
        XCTAssertEqual(rows.count, 5)
    }

    // MARK: - Helpers

    private func pad(_ text: String, _ width: Int) -> String {
        if text.count >= width { return text }
        return text + String(repeating: " ", count: width - text.count)
    }

    private func loadPersonaFile(_ name: String) throws -> String {
        let url = personasDir.appendingPathComponent("\(name).txt")
        return try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func prepared(_ name: String) throws -> String {
        PromptBudget.preparedForMeasurement(try loadPersonaFile(name))
    }
}
