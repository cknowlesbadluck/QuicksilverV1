import SwiftUI
import Core

/// Unified visual system for Quicksilver.
/// One theme per active Aspect, enforced by the SwiftUI environment.
enum PersonaTheme {
    // MARK: - Aspect identity

    static func accent(for aspectID: String) -> Color {
        switch aspectID {
        case Aspect.quicksilver.rawValue: return mercuryAqua
        case Aspect.forge.rawValue: return mercuryOrange
        case Aspect.eternal.rawValue: return mercuryPurple
        default: return mercuryAqua
        }
    }

    static func secondaryAccent(for aspectID: String) -> Color {
        switch aspectID {
        case Aspect.quicksilver.rawValue: return mercuryBright
        case Aspect.forge.rawValue: return mercuryRed
        case Aspect.eternal.rawValue: return mercuryViolet
        default: return mercuryBright
        }
    }

    // MARK: - Core palette

    static let mercurySilver = Color(red: 0.92, green: 0.92, blue: 0.94)
    static let mercuryBright = Color(red: 0.98, green: 0.98, blue: 1.0)
    static let mercuryDark = Color(red: 0.08, green: 0.08, blue: 0.12)

    // MARK: - Aspect colors

    static let mercuryAqua = Color(red: 0.18, green: 0.88, blue: 0.92) // Quicksilver
    static let mercuryOrange = Color(red: 1.0, green: 0.68, blue: 0.20) // Forge
    static let mercuryPurple = Color(red: 0.68, green: 0.48, blue: 0.92) // Eternal

    static let mercuryRed = Color(red: 1.0, green: 0.35, blue: 0.42) // Forge secondary
    static let mercuryViolet = Color(red: 0.78, green: 0.38, blue: 0.92) // Eternal secondary

    // MARK: - Contextual palette

    static let successGreen = Color(red: 0.32, green: 0.92, blue: 0.62)
    static let warningYellow = Color(red: 1.0, green: 0.82, blue: 0.18)
    static let criticalRed = Color(red: 1.0, green: 0.35, blue: 0.42)

    // MARK: - Intensity & ambient

    static func ambientIntensity(for aspectID: String) -> Double {
        switch aspectID {
        case Aspect.forge.rawValue: return 1.2
        case Aspect.eternal.rawValue: return 0.8
        default: return 1.0 // Quicksilver
        }
    }

    // MARK: - Motion

    static let motionSlowFade = Animation.easeInOut(duration: 0.45)
    static let motionResponsive = Animation.easeInOut(duration: 0.22)
    static let motionSnappy = Animation.easeOut(duration: 0.15)

    // MARK: - Semantic status

    static func statusColor(for state: String) -> Color {
        switch state.lowercased() {
        case "success", "ready":
            return successGreen
        case "warning", "thinking":
            return warningYellow
        case "error", "failed":
            return criticalRed
        default:
            return mercurySilver
        }
    }

    static func statusOpacity(for state: String) -> Double {
        switch state.lowercased() {
        case "idle", "sleeping":
            return 0.5
        case "thinking", "processing":
            return 0.7
        default:
            return 1.0
        }
    }

    // MARK: - Typography

    static let headlineFont = Font.system(.headline, design: .default).weight(.semibold)
    static let subheadlineFont = Font.system(.subheadline, design: .default).weight(.medium)
    static let captionFont = Font.system(.caption, design: .monospaced).weight(.regular)

    // MARK: - Spacing

    static let gridSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 16
    static let verticalPadding: CGFloat = 20

    // MARK: - Shadow & depth

    static let subtleShadow = Shadow(
        color: Color.black.opacity(0.08),
        radius: 4,
        x: 0,
        y: 2
    )

    static let emphasizedShadow = Shadow(
        color: Color.black.opacity(0.16),
        radius: 8,
        x: 0,
        y: 4
    )

    // MARK: - Cornerstone design decision

    static func indicatorColor(for level: String) -> Color {
        switch level {
        case "critical":
            return criticalRed
        case "warning":
            return warningYellow
        case "success":
            return successGreen
        default:
            return mercurySilver
        }
    }

    // MARK: - Sanctum field (place, not a board)

    /// Optical center of the living core, as a fraction of the field.
    static let sanctumCoreX: CGFloat = 0.50
    static let sanctumCoreY: CGFloat = 0.46
    /// Portal control size before depth scale. Far portals stay ≥ 44 pt.
    static let sanctumPortalHit: CGFloat = 56
    static let sanctumPortalFarScale: CGFloat = 0.86
    static let sanctumPortalNearScale: CGFloat = 1.12
    static let sanctumStarCount: Int = 42

    static func sanctumPortalScale(depth: CGFloat) -> CGFloat {
        sanctumPortalFarScale + (sanctumPortalNearScale - sanctumPortalFarScale) * depth
    }
}

// MARK: - Shadow token

/// Internal (not private): `PersonaTheme.subtleShadow` / `.emphasizedShadow` expose it.
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}
