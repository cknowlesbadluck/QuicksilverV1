import SwiftUI
import Personas

/// Full design token system for Mercury: Quicksilver.
/// Controlled chaos radioactivity: void black · glow purple · toxic green · hazard green · mercury silver.
/// Tokens are persona-reactive where it serves identity; the overall identity is Mercury.
enum PersonaTheme {

    // MARK: - Core Palette (Radioactive Mercury Identity)

    static let voidBlack = Color(red: 0.020, green: 0.020, blue: 0.039)
    static let glowPurple = Color(red: 0.545, green: 0.239, blue: 1.000)
    static let toxicGreen = Color(red: 0.220, green: 0.949, blue: 0.353)
    static let hazardGreen = Color(red: 0.086, green: 0.639, blue: 0.290)
    static let mercurySilver = Color(red: 0.784, green: 0.800, blue: 0.831)

    // Controlled-chaos material language.
    static let chaosBlack = Color(red: 0.006, green: 0.008, blue: 0.012)
    static let mercuryBright = Color(red: 0.940, green: 0.965, blue: 1.000)
    static let mercuryShadow = Color(red: 0.180, green: 0.205, blue: 0.235)
    static let mercuryBlue = Color(red: 0.380, green: 0.560, blue: 0.720)

    // Absorbed from MercuryVisualTokens (M1-T11) — atmosphere + instrument accents.
    static let sanctumPurple = Color(red: 0.220, green: 0.105, blue: 0.360)
    static let quicksilver = Color(red: 0.350, green: 0.950, blue: 0.720)
    static let quicksilverDeep = Color(red: 0.090, green: 0.280, blue: 0.220)
    static let ember = Color(red: 0.780, green: 0.340, blue: 0.180)
    static let eternalGold = Color(red: 0.780, green: 0.650, blue: 0.300)
    static let panel = Color(red: 0.055, green: 0.045, blue: 0.090)
    static let warningEmber = Color(red: 0.95, green: 0.35, blue: 0.2)
    static let criticalRed = Color(red: 0.95, green: 0.25, blue: 0.28)

    // Legacy aliases so existing call-sites compile while migrating.
    static let cosmicBlack = voidBlack
    static let deepViolet = glowPurple
    static let emeraldAccent = toxicGreen
    static let subtleGold = hazardGreen
    static let liquidMetal = mercurySilver.opacity(0.72)

    // MARK: - Controlled Chaos Geometry

    /// One shared visual grammar: irregular enough to feel alive, bounded enough to feel intentional.
    static let chaosSeedCount = 13
    static let chaosFieldOpacity = 0.18
    static let chaosTraceOpacity = 0.26
    static let chaosTraceLineWidth: CGFloat = 0.7
    static let chaosCoreRadius: CGFloat = 1.0
    static let chaosCoreBloom: CGFloat = 2.25
    static let chaosOrbitalRadius: CGFloat = 0.72
    static let chaosParticleRadius: CGFloat = 0.022
    static let chaosSurfaceOpacity = 0.72
    static let chaosGlassOpacity = 0.10

    // MARK: - Surface Geometry (absorbed from MercuryVisualTokens)

    static let glassCornerRadius: CGFloat = 18
    static let largeCornerRadius: CGFloat = 26

    // MARK: - Persona Accents

    static func accent(for personaID: String) -> Color {
        switch personaID.lowercased() {
        case "forge": return toxicGreen
        case "eternal": return glowPurple
        case "quicksilver": return mercurySilver
        default: return toxicGreen
        }
    }

    static func secondaryAccent(for personaID: String) -> Color {
        switch personaID.lowercased() {
        case "forge": return glowPurple
        case "eternal": return toxicGreen.opacity(0.85)
        default: return glowPurple
        }
    }

    static func ambientIntensity(for personaID: String) -> Double {
        switch personaID.lowercased() {
        case "forge": return 0.82
        case "eternal": return 0.58
        default: return 0.45
        }
    }

    // MARK: - Density & Geometry

    static func density(for personaID: String) -> CGFloat {
        switch personaID.lowercased() {
        case "forge": return 0.85
        case "eternal": return 1.18
        default: return 1.0
        }
    }

    static func cardCornerRadius(for personaID: String) -> CGFloat {
        switch personaID.lowercased() {
        case "forge": return 12
        case "eternal": return 22
        default: return 16
        }
    }

    static func glassOpacity(for personaID: String) -> Double {
        switch personaID.lowercased() {
        case "forge": return 0.14
        case "eternal": return 0.09
        default: return 0.12
        }
    }

    // MARK: - Typography & Bubbles

    static func assistantBubbleStyle(for personaID: String) -> (opacity: Double, weight: Font.Weight) {
        switch personaID.lowercased() {
        case "forge": return (0.12, .medium)
        case "eternal": return (0.09, .regular)
        default: return (0.13, .regular)
        }
    }

    // MARK: - Motion Curves

    static func spring(for personaID: String) -> Animation {
        switch personaID.lowercased() {
        case "forge": return .spring(response: 0.30, dampingFraction: 0.84)
        case "eternal": return .spring(response: 0.55, dampingFraction: 0.78)
        default: return .spring(response: 0.40, dampingFraction: 0.76)
        }
    }

    static let thinkingPulse = Animation.easeInOut(duration: 1.35).repeatForever(autoreverses: true)
    static let insightAppear = Animation.spring(response: 0.48, dampingFraction: 0.72)

    // MARK: - Materials & Borders

    static func cardBackground(for personaID: String) -> some ShapeStyle { .ultraThinMaterial }

    static func borderColor(for personaID: String) -> Color {
        accent(for: personaID).opacity(0.40)
    }

    static func radioactiveStroke(for personaID: String, intensity: Double = 1.0) -> Color {
        let base = personaID.lowercased() == "forge" ? toxicGreen : glowPurple
        return base.opacity(0.35 * intensity)
    }

    // MARK: - Policy Summary

    static func policySummary(for personaID: String) -> String {
        let policy = MemoryPolicy.policy(for: personaID)
        let threshold = Int(policy.retentionThreshold * 100)
        let scope = policy.prefersScopedView ? "scoped" : "shared"
        let write = policy.writeImportanceHint.map { Int($0 * 100) }.map { "write \($0)%" } ?? "write default"
        return "\(threshold)% retain · \(scope) · \(write)"
    }

    // MARK: - Living Status Colors

    static func healthColor(_ score: Int) -> Color {
        switch score {
        case 80...: return toxicGreen
        case 50..<80: return hazardGreen
        default: return criticalRed
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
