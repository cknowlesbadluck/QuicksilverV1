import CoreSpotlight
import XCTest
@testable import QuicksilverIntents

/// A Spotlight result tap reaches the note it was indexed for, and nothing else is routed.
final class NoteSpotlightRouteTests: XCTestCase {
    private func activity(type: String, identifier: Any?) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type)
        if let identifier { activity.userInfo = [CSSearchableItemActivityIdentifier: identifier] }
        return activity
    }

    func testSpotlightTapResolvesTheIndexedNoteID() {
        let id = UUID()
        XCTAssertEqual(NoteSpotlightRoute.noteID(from: activity(type: CSSearchableItemActionType, identifier: id.uuidString)), id)
    }

    func testOtherActivityTypesAreIgnored() {
        XCTAssertNil(NoteSpotlightRoute.noteID(from: activity(type: "com.example.other", identifier: UUID().uuidString)))
    }

    func testMissingOrMalformedIdentifierIsIgnored() {
        XCTAssertNil(NoteSpotlightRoute.noteID(from: activity(type: CSSearchableItemActionType, identifier: nil)))
        XCTAssertNil(NoteSpotlightRoute.noteID(from: activity(type: CSSearchableItemActionType, identifier: "note.1")))
        XCTAssertNil(NoteSpotlightRoute.noteID(from: activity(type: CSSearchableItemActionType, identifier: 42)))
    }
}
