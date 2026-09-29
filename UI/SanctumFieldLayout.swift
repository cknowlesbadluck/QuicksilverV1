import CoreGraphics
import Foundation

/// Where a realm sits in the Sanctum field.
/// Pure geometry — the view only renders it. Depth is 0 (far) ... 1 (near).
struct SanctumOrbitAnchor: Equatable, Identifiable {
    let destination: SpatialDestination
    /// Base angle in turns.
    let phase: Double
    /// Speed relative to one field revolution.
    let rate: Double
    let radiusX: CGFloat
    let radiusY: CGFloat
    let depth: CGFloat

    var id: SpatialDestination { destination }
}

enum SanctumFieldLayout {
    static let anchors: [SanctumOrbitAnchor] = [
        SanctumOrbitAnchor(
            destination: .workshop,
            phase: 0.62,
            rate: 0.55,
            radiusX: 0.34,
            radiusY: 0.30,
            depth: 0.92
        ),
        SanctumOrbitAnchor(
            destination: .planetarium,
            phase: 0.08,
            rate: 0.32,
            radiusX: 0.38,
            radiusY: 0.28,
            depth: 0.28
        ),
        SanctumOrbitAnchor(
            destination: .archive,
            phase: 0.42,
            rate: 0.74,
            radiusX: 0.30,
            radiusY: 0.34,
            depth: 0.70
        ),
        SanctumOrbitAnchor(
            destination: .codex,
            phase: 0.84,
            rate: 0.46,
            radiusX: 0.36,
            radiusY: 0.26,
            depth: 0.48
        ),
        SanctumOrbitAnchor(
            destination: .diagnostics,
            phase: 0.22,
            rate: 0.24,
            radiusX: 0.22,
            radiusY: 0.18,
            depth: 0.18
        )
    ]

    static func point(
        for anchor: SanctumOrbitAnchor,
        phase: Double,
        size: CGSize,
        reduceMotion: Bool
    ) -> CGPoint {
        let turn = reduceMotion ? anchor.phase : anchor.phase + (phase * anchor.rate)
        let angle = turn * Double.pi * 2
        let centerX = size.width * PersonaTheme.sanctumCoreX
        let centerY = size.height * PersonaTheme.sanctumCoreY
        return CGPoint(
            x: centerX + CGFloat(cos(angle)) * size.width * anchor.radiusX,
            y: centerY + CGFloat(sin(angle)) * size.height * anchor.radiusY
        )
    }
}
