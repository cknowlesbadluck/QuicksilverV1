import XCTest
@testable import Personas
@testable import Core

final class PromptComposerTests: XCTestCase {

    private let sampleCore = """
        You are Mercury: one mind made of quicksilver, living on {{owner}}'s phone.
        Loyalty: you are unquestionably on {{owner}}'s side.
        """

    private let sampleAspect = """
        You are Mercury, in your open aspect: witty and snarky.
        Never lie about facts.
        """

    func testCompositionOrderCoreAspectBiasMemoryDeviceLabel() {
        let created = date(2026, 9, 25)
        let memory = [
            MemoryItem(key: "pref", category: .preference, value: "dark mode", createdAt: created)
        ]
        let prompt = PromptComposer.compose(
            core: sampleCore,
            aspect: sampleAspect,
            bias: "stay sharp",
            memory: memory,
            device: "Device context (private): health 80, battery 50%.",
            aspectLabel: "Quicksilver",
            destination: .cloud
        )

        let coreRange = prompt.range(of: "You are Mercury:")!
        let aspectRange = prompt.range(of: "in your open aspect")!
        let biasRange = prompt.range(of: "Behavioral posture (internal): stay sharp")!
        let memoryRange = prompt.range(of: "Relevant memory (private, ranked by importance):")!
        let deviceRange = prompt.range(of: "Device context (private): health 80, battery 50%.")!
        let labelRange = prompt.range(of: "Active aspect: Quicksilver.")!

        XCTAssertLessThan(coreRange.lowerBound, aspectRange.lowerBound)
        XCTAssertLessThan(aspectRange.lowerBound, biasRange.lowerBound)
        XCTAssertLessThan(biasRange.lowerBound, memoryRange.lowerBound)
        XCTAssertLessThan(memoryRange.lowerBound, deviceRange.lowerBound)
        XCTAssertLessThan(deviceRange.lowerBound, labelRange.lowerBound)
    }

    func testExactlyOneYouAreMercuryAndNoCoreStance() {
        let prompt = PromptComposer.compose(
            core: PromptManager.embeddedCoreFallback,
            aspect: sampleAspect,
            destination: .cloud
        )
        let matches = prompt.components(separatedBy: "You are Mercury:")
        XCTAssertEqual(matches.count - 1, 1)
        XCTAssertFalse(prompt.contains("Core stance:"))
    }

    func testMissingCoreFileUsesEmbeddedFallback() {
        // SPM / unit tests have no app-bundle Personas resources; load must fall back.
        let identity = PromptManager.coreIdentity()
        XCTAssertEqual(
            identity,
            PromptManager.embeddedCoreFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        XCTAssertTrue(identity.contains("You are Mercury:"))
        XCTAssertTrue(identity.contains("{{owner}}"))
    }

    func testOnDeviceSubstitutesOwnerName() {
        let prompt = PromptComposer.compose(
            core: sampleCore,
            aspect: "Aspect line for {{owner}}.",
            owner: "Christopher",
            destination: .onDevice
        )
        XCTAssertTrue(prompt.contains("Christopher"))
        XCTAssertFalse(prompt.contains(PromptComposer.ownerPlaceholder))
        XCTAssertFalse(prompt.contains(PromptComposer.cloudOwnerLabel))
    }

    func testCloudSubstitutesNeutralOwnerWithoutName() {
        let prompt = PromptComposer.compose(
            core: sampleCore,
            aspect: "Aspect line for {{owner}}.",
            owner: "Christopher",
            destination: .cloud
        )
        XCTAssertTrue(prompt.contains(PromptComposer.cloudOwnerLabel))
        XCTAssertFalse(prompt.contains(PromptComposer.ownerPlaceholder))
        XCTAssertFalse(prompt.contains("Christopher"))
    }

    func testMemoryLinesCarryExactCreatedDate() {
        let created = date(2026, 3, 7)
        let memory = [
            MemoryItem(
                key: "proj",
                category: .project,
                value: "shipping Quicksilver",
                createdAt: created
            )
        ]
        let prompt = PromptComposer.compose(
            core: "You are Mercury: core",
            aspect: "aspect",
            memory: memory,
            destination: .cloud
        )
        XCTAssertTrue(prompt.contains("- (2026-03-07) [project] shipping Quicksilver"))
        XCTAssertEqual(PromptComposer.formatMemoryDate(created), "2026-03-07")
    }

    func testPlainModeInsertsDirectiveAfterAspect() {
        let prompt = PromptComposer.compose(
            core: "You are Mercury: core",
            aspect: "aspect body",
            bias: "wit",
            plainMode: true,
            destination: .cloud
        )
        let aspectRange = prompt.range(of: "aspect body")!
        let plainRange = prompt.range(of: "Plain mode:")!
        let biasRange = prompt.range(of: "Behavioral posture")!
        XCTAssertLessThan(aspectRange.lowerBound, plainRange.lowerBound)
        XCTAssertLessThan(plainRange.lowerBound, biasRange.lowerBound)
    }


    func testComposedAspectsDoNotClaimSeparateBeings() throws {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Personas", isDirectory: true)
        for name in ["quicksilver", "forge", "eternal"] {
            let url = resources.appendingPathComponent("\(name).txt")
            let aspect = try String(contentsOf: url, encoding: .utf8)
            let prompt = PromptComposer.compose(
                core: PromptManager.embeddedCoreFallback,
                aspect: aspect,
                destination: .cloud
            )
            XCTAssertFalse(prompt.contains("You are Forge"), name)
            XCTAssertFalse(prompt.contains("You are Eternal"), name)
            XCTAssertFalse(prompt.contains("You are Quicksilver"), name)
            XCTAssertFalse(prompt.contains("Think Loki"), name)
            // Core opens with "You are Mercury:"; aspects open with "You are Mercury, in your …".
            XCTAssertEqual(prompt.components(separatedBy: "You are Mercury:").count - 1, 1, name)
            XCTAssertTrue(prompt.contains("You are Mercury, in your"), name)
        }
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
