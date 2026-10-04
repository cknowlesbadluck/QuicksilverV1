import Foundation
import XCTest
@testable import Core
@testable import ServicesAI

final class HistoryBudgetTests: XCTestCase {
    func testBlankTurnsAreDroppedAndNewestTwelveAreKept() {
        var history: [Message] = [Message(role: .user, content: "   ")]
        for index in 0..<13 {
            history.append(Message(role: index.isMultiple(of: 2) ? .user : .assistant, content: "turn-\(index)"))
        }
        let window = HistoryBudget.window(history)
        XCTAssertEqual(window.turns.count, 12)
        XCTAssertEqual(window.turns.first?.content, "turn-1")
        XCTAssertEqual(window.turns.last?.content, "turn-12")
        XCTAssertEqual(window.droppedTurns, 2)
        XCTAssertEqual(window.truncatedTurns, 0)
    }

    func testOversizedTurnIsTruncatedNotSentWhole() {
        let huge = String(repeating: "a", count: HistoryBudget.maxCharactersPerTurn + 25)
        let window = HistoryBudget.window([Message(role: .assistant, content: huge)])
        XCTAssertEqual(window.turns.count, 1)
        XCTAssertEqual(window.turns[0].content.count, HistoryBudget.maxCharactersPerTurn)
        XCTAssertEqual(window.truncatedTurns, 1)
        XCTAssertEqual(window.droppedTurns, 0)
    }

    func testGatewayBodyUsesWindowNotRawHistory() {
        var history: [Message] = []
        for index in 0..<14 {
            history.append(Message(role: .user, content: "h-\(index)"))
        }
        let body = GatewayRequest.makeChatBody(AIRequest(prompt: "now", history: history, maxTokens: 32))
        let prior = body.messages.dropLast()
        XCTAssertEqual(prior.count, 12)
        XCTAssertEqual(prior.first?.content, "h-2")
        XCTAssertEqual(body.messages.last?.content, "now")
        XCTAssertEqual(body.messages.last?.role, "user")
    }
}
