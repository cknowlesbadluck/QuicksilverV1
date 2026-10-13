import Foundation
import XCTest

/// Source-level guards for the architecture invariants in AGENTS.md:
/// one MercuryBrain path, the CloudContextPolicy choke point, aspects (not
/// modes) and no committed secrets. They read the repository sources, so a
/// regression fails CI before it can reach a device.
final class ArchitectureInvariantTests: XCTestCase {

    private static let repoRoot: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static let skippedDirectories: Set<String> = [
        ".git", ".build", "node_modules", "DerivedData", "build", ".wrangler"
    ]

    private func files(in directories: [String], extensions: Set<String>) throws -> [(path: String, text: String)] {
        var result: [(String, String)] = []
        let fileManager = FileManager.default
        for directory in directories {
            let base = Self.repoRoot.appendingPathComponent(directory)
            guard fileManager.fileExists(atPath: base.path) else { continue }
            guard let walker = fileManager.enumerator(at: base, includingPropertiesForKeys: [.isDirectoryKey]) else {
                continue
            }
            for case let url as URL in walker {
                if Self.skippedDirectories.contains(url.lastPathComponent) {
                    walker.skipDescendants()
                    continue
                }
                guard extensions.contains(url.pathExtension) else { continue }
                let relative = String(url.path.dropFirst(Self.repoRoot.path.count + 1))
                result.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return result
    }

    func testRepositoryRootIsResolvable() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.repoRoot.appendingPathComponent("App/MercuryBrain.swift").path),
            "ArchitectureInvariantTests could not locate the repo root"
        )
    }

    /// Only MercuryBrain may ask the AI service for a completion; UI, Intents
    /// and the container go through the Brain / IntelligenceSurface.
    func testOnlyMercuryBrainRequestsCompletions() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Nexus", "Memory", "Personas"], extensions: ["swift"])
        XCTAssertFalse(sources.isEmpty)
        let offenders = sources.filter { file in
            !file.path.hasPrefix("App/MercuryBrain")
                && (file.text.contains("aiService.complete(") || file.text.contains("aiService.complete\n"))
        }.map(\.path)
        XCTAssertEqual(offenders, [], "Completions must route through MercuryBrain")
    }

    /// Concrete providers are built only inside Services/AI (AIService owns them).
    func testProvidersAreConstructedOnlyInsideServicesAI() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Core", "Memory", "Personas", "Nexus"], extensions: ["swift"])
        let constructors = ["GatewayAIProvider(", "GeminiAIProvider(", "GrokAIProvider("]
        let offenders = sources.filter { file in
            constructors.contains { file.text.contains($0) }
        }.map(\.path)
        XCTAssertEqual(offenders, [], "Providers must be created by AIService, not callers")
    }

    /// The cloud choke point stays wired: AIService redacts through
    /// CloudContextPolicy and the Brain assembles context with it.
    func testCloudContextPolicyRemainsTheChokePoint() throws {
        let service = try files(in: ["Services/AI"], extensions: ["swift"])
        let aiService = try XCTUnwrap(service.first { $0.path == "Services/AI/AIService.swift" })
        XCTAssertTrue(aiService.text.contains("CloudContextPolicy."), "AIService must redact via CloudContextPolicy")

        let brain = try files(in: ["App"], extensions: ["swift"]).filter { $0.path.hasPrefix("App/MercuryBrain") }
        XCTAssertTrue(
            brain.contains { $0.text.contains("CloudContextPolicy") },
            "MercuryBrain must assemble cloud context via CloudContextPolicy"
        )
    }

    /// Aspects are moods of one entity, never user-selectable "modes".
    func testNoModeVocabularyForAspects() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Core", "Personas"], extensions: ["swift"])
        let banned = ["PersonaMode", "AspectMode", "selectedMode", "enum Mode "]
        let offenders = sources.filter { file in banned.contains { file.text.contains($0) } }.map(\.path)
        XCTAssertEqual(offenders, [], "Use Aspect vocabulary, not modes")
    }

    /// No provider key or token is ever committed.
    func testNoSecretsCommitted() throws {
        let sources = try files(
            in: ["App", "AppTests", "Core", "Intents", "Memory", "Nexus", "Personas", "Services", "Tests", "UI", "UITests",
                 "Resources", "gateway", ".github", "scripts", "docs", "Documentation", "fastlane"],
            extensions: ["swift", "ts", "js", "mjs", "json", "yml", "yaml", "toml", "plist", "sh", "md", "txt", "xcconfig"]
        )
        let patterns = [
            #"AIza[0-9A-Za-z_\-]{35}"#,          // Google / Gemini
            #"gsk_[0-9A-Za-z]{40,}"#,            // Groq
            #"xai-[0-9A-Za-z]{40,}"#,            // xAI
            #"sk-[0-9A-Za-z]{40,}"#,             // OpenAI-style
            #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#
        ].map { try? NSRegularExpression(pattern: $0) }.compactMap { $0 }
        XCTAssertEqual(patterns.count, 5)

        var offenders: [String] = []
        for file in sources {
            let range = NSRange(file.text.startIndex..., in: file.text)
            if patterns.contains(where: { $0.firstMatch(in: file.text, range: range) != nil }) {
                offenders.append(file.path)
            }
        }
        XCTAssertEqual(offenders, [], "Secret-shaped strings found in source")
    }
}
