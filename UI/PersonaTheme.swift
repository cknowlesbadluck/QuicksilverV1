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
    /// Body copy on void. Full silver stays above WCAG AA for caption text.
    static let readableText = mercurySilver
    /// Secondary copy. Still above the 0.55 opacity that failed the Sanctum audit.
    static let readableSecondary = Color(red: 0.910, green: 0.918, blue: 0.935)

    // Controlled-chaos material language.
    static let chaosBlack = Color(red: 0.006, green: 0.008, blue: 0.012)
    static let mercuryBright = Color(red: 0.940, green: 0.965, blue: 1.000)
    static let mercuryShadow = Color(red: 0.180, green: 0.205, blue: 0.235)

    // Absorbed from MercuryVisualTokens (M1-T11) — atmosphere + instrument accents.
    static let sanctumPurple = Color(red: 0.220, green: 0.105, blue: 0.360)
    static let quicksilver = Color(red: 0.350, green: 0.950, blue: 0.720)
    static let quicksilverDeep = Color(red: 0.090, green: 0.280, blue: 0.220)
    static let panel = Color(red: 0.055, green: 0.045, blue: 0.090)
    static let warningEmber = Color(red: 0.95, green: 0.35, blue: 0.2)

    // Legacy aliases so existing call-sites compile while migrating.
    static let cosmicBlack = voidBlack
    static let subtleGold = hazardGreen

    // MARK: - Controlled Chaos Geometry

    /// One shared visual grammar: irregular enough to feel alive, bounded enough to feel intentional.
    static let chaosSeedCount = 13
    static let chaosFieldOpacity = 0.18
    static let chaosTraceLineWidth: CGFloat = 0.7
    static let chaosCoreRadius: CGFloat = 1.0
    static let chaosCoreBloom: CGFloat = 2.25
    static let chaosOrbitalRadius: CGFloat = 0.72
    static let chaosParticleRadius: CGFloat = 0.022

    // MARK: - Surface Geometry (absorbed from MercuryVisualTokens)

    static let glassCornerRadius: CGFloat = 18

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

    // MARK: - Materials & Borders

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
}
