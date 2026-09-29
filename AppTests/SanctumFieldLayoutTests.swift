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

    func testReduceMotionFreezesTheField() throws {
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

    func testOpenMotionActuallyDrifts() throws {
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

    func testPortalsStayInsideTheField() throws {
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

    func testMinimumPortalSeparation() throws {
        /// Minimum button separation across the full 96-second orbit.
        let minimumSeparation: CGFloat = 68 // ~portal hit size + padding
        for anchor in SanctumFieldLayout.anchors {
            for other in SanctumFieldLayout.anchors where other.id != anchor.id {
                for step in 0..<16 { // Sample 16 points in one cycle
                    let phase = Double(step) / 16
                    let point1 = SanctumFieldLayout.point(
                        for: anchor,
                        phase: phase,
                        size: field,
                        reduceMotion: false
                    )
                    let point2 = SanctumFieldLayout.point(
                        for: other,
                        phase: phase,
                        size: field,
                        reduceMotion: false
                    )
                    let distance = hypot(point1.x - point2.x, point1.y - point2.y)
                    XCTAssertGreaterThanOrEqual(
                        distance,
                        minimumSeparation,
                        "\(anchor.destination) and \(other.destination) collide at phase \(phase)"
                    )
                }
            }
        }
    }
}
