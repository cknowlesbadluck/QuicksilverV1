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

    private static let brainFiles: Set<String> = [
        "App/MercuryBrain.swift", "App/MercuryBrain+Capabilities.swift",
        "App/MercuryBrain+Ranking.swift", "App/MercuryBrain+TurnHelpers.swift",
        "App/MercuryBrainComposition.swift"
    ]

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

    private func rootFiles(extensions: Set<String>) throws -> [(path: String, text: String)] {
        try FileManager.default.contentsOfDirectory(at: Self.repoRoot, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { extensions.contains($0.pathExtension) }
            .map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    func testRepositoryRootIsResolvable() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: Self.repoRoot.appendingPathComponent("App/MercuryBrain.swift").path),
            "ArchitectureInvariantTests could not locate the repo root"
        )
    }

    /// Only MercuryBrain may ask the AI service for a completion; UI, Intents
    /// and the container go through the Brain / IntelligenceSurface. Any file
    /// outside MercuryBrain that touches the AI service must not call
    /// `.complete(` on anything, whatever the local variable is called.
    func testOnlyMercuryBrainRequestsCompletions() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Nexus", "Memory", "Personas", "Services"], extensions: ["swift"])
        XCTAssertFalse(sources.isEmpty)
        let offenders = sources.filter { file in
            guard !Self.brainFiles.contains(file.path), !file.path.hasPrefix("Services/AI/") else { return false }
            let touchesService = file.text.contains("aiService") || file.text.contains("AIService")
            return touchesService && file.text.range(of: #"\.complete\s*\("#, options: .regularExpression) != nil
        }.map(\.path)
        XCTAssertEqual(offenders, [], "Completions must route through MercuryBrain")
    }

    /// Concrete providers are built only inside Services/AI (AIService owns them),
    /// via initializer, `.init` or static factory.
    func testProvidersAreConstructedOnlyInsideServicesAI() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Core", "Memory", "Personas", "Nexus", "Services"], extensions: ["swift"])
        let pattern = #"\b(GatewayAIProvider|GeminiAIProvider|GrokAIProvider)\s*(\(|\.init\b|\.make\b)"#
        let offenders = sources.filter { file in
            !file.path.hasPrefix("Services/AI/") && file.text.range(of: pattern, options: .regularExpression) != nil
        }.map(\.path)
        XCTAssertEqual(offenders, [], "Providers must be created by AIService, not callers")
    }

    /// The cloud choke point stays wired: AIService redacts through
    /// CloudContextPolicy and the Brain assembles context with it.
    func testCloudContextPolicyRemainsTheChokePoint() throws {
        let service = try files(in: ["Services/AI"], extensions: ["swift"])
        let aiService = try XCTUnwrap(service.first { $0.path == "Services/AI/AIService.swift" })
        XCTAssertTrue(aiService.text.contains("CloudContextPolicy."), "AIService must redact via CloudContextPolicy")

        XCTAssertTrue(aiService.text.contains("CloudContextPolicy.redactForTrainingProvider("))

        let brain = try files(in: ["App"], extensions: ["swift"])
            .filter { Self.brainFiles.contains($0.path) }
            .map(\.text).joined(separator: "\n")
        for call in ["assemble(", "cappedHistory(", "gatewayContext(", "resolvedLevel("] {
            XCTAssertTrue(
                brain.contains("CloudContextPolicy.\(call)"),
                "MercuryBrain must build cloud payloads via CloudContextPolicy.\(call)"
            )
        }
    }

    /// Aspects are moods of one entity, never user-selectable "modes".
    func testNoModeVocabularyForAspects() throws {
        let sources = try files(in: ["App", "UI", "Intents", "Core", "Personas"], extensions: ["swift"])
        let pattern = #"\b(PersonaMode|AspectMode|selectedAspectMode|(Quicksilver|Forge|Eternal)Mode)\b"#
        let offenders = sources.filter { $0.text.range(of: pattern, options: .regularExpression) != nil }.map(\.path)
        XCTAssertEqual(offenders, [], "Use Aspect vocabulary, not modes")
    }

    /// No provider key or token is ever committed.
    func testNoSecretsCommitted() throws {
        let sources = try files(
            in: ["App", "AppTests", "Core", "Intents", "Memory", "Nexus", "Personas", "Services", "Tests", "UI", "UITests",
                 "Resources", "gateway", ".github", "scripts", "docs", "Documentation", "fastlane"],
            extensions: ["swift", "ts", "js", "mjs", "json", "yml", "yaml", "toml", "plist", "sh", "md", "txt", "xcconfig"]
        ) + rootFiles(extensions: ["swift", "yml", "yaml", "md", "json", "plist", "xcprivacy", "toml", "example", "sample"])
        let patterns = [
            #"AIza[0-9A-Za-z_\-]{35}"#,          // Google / Gemini
            #"gsk_[0-9A-Za-z]{40,}"#,            // Groq
            #"xai-[0-9A-Za-z]{40,}"#,            // xAI
            #"sk-[0-9A-Za-z]{40,}"#,             // OpenAI-style
            #"-----BEGIN [A-Z ]*PRIVATE KEY-----"#,
            #"DEVICE_TOKEN\s*[=:]\s*["']?[0-9A-Za-z_\-]{32,}"#   // gateway device token assignment
        ].map { try? NSRegularExpression(pattern: $0) }.compactMap { $0 }
        XCTAssertEqual(patterns.count, 6)

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
