import XCTest
import CoreGraphics
@testable import Quicksilver

final class SanctumFieldLayoutTests: XCTestCase {
    private let field = CGSize(width: 390, height: 844)

    func testEveryRealmHasOneOrbit() {
        let ids = SanctumFieldLayout.anchors.map(\.destination)
        XCTAssertEqual(Set(ids), Set(SpatialDestination.allCases))
        XCTAssertEqual(ids.count, SpatialDestination.allCases.count)
    }

    func testReduceMotionFreezesTheField() {
        let anchor = try XCTUnwrap(SanctumFieldLayout.anchors.first)
        let still = SanctumFieldLayout.point(
            for: anchor,
            phase: 0,
            size: field,
            reduceMotion: true
        )
        let later = SanctumFieldLayout.point(
            for: anchor,
            phase: 0.5,
            size: field,
            reduceMotion: true
        )
        XCTAssertEqual(still, later)
    }

    func testOpenMotionActuallyDrifts() {
        let anchor = try XCTUnwrap(
            SanctumFieldLayout.anchors.first { $0.rate > 0 }
        )
        let start = SanctumFieldLayout.point(
            for: anchor,
            phase: 0,
            size: field,
            reduceMotion: false
        )
        let later = SanctumFieldLayout.point(
            for: anchor,
            phase: 0.35,
            size: field,
            reduceMotion: false
        )
        XCTAssertNotEqual(start, later)
    }

    func testPortalsStayInsideTheField() {
        for anchor in SanctumFieldLayout.anchors {
            for step in 0..<8 {
                let point = SanctumFieldLayout.point(
                    for: anchor,
                    phase: Double(step) / 8,
                    size: field,
                    reduceMotion: false
                )
                XCTAssertGreaterThan(point.x, 24, anchor.destination.rawValue)
                XCTAssertLessThan(point.x, field.width - 24, anchor.destination.rawValue)
                XCTAssertGreaterThan(point.y, 48, anchor.destination.rawValue)
                XCTAssertLessThan(point.y, field.height - 48, anchor.destination.rawValue)
            }
        }
    }
}
