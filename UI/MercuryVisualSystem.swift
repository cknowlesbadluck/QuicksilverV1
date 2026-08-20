import SwiftUI

/// Visual language for Mercury: Quicksilver.
///
/// The system deliberately avoids dashboard chrome. Surfaces behave like
/// instruments inside a dark chamber: layered atmosphere, metallic text,
/// restrained glass, and a living mercury core.
enum MercuryVisualTokens {
    static let void = Color(red: 0.035, green: 0.024, blue: 0.067)
    static let sanctumPurple = Color(red: 0.427, green: 0.298, blue: 0.608)
    static let quicksilver = Color(red: 0.725, green: 1.000, blue: 0.000)
    static let quicksilverDeep = Color(red: 0.180, green: 0.235, blue: 0.030)
    static let silver = Color(red: 0.720, green: 0.700, blue: 0.780)
    static let ember = Color(red: 0.780, green: 0.340, blue: 0.180)
    static let eternalGold = Color(red: 0.780, green: 0.650, blue: 0.300)
    static let panel = Color(red: 0.082, green: 0.063, blue: 0.129)

    static let cornerRadius: CGFloat = 16
    static let largeCornerRadius: CGFloat = 24
    static let corePulseDuration: TimeInterval = 3.6
    static let realmTransitionDuration: TimeInterval = 0.42
    static let microInteractionDuration: TimeInterval = 0.16
}

/// Atmospheric foundation for the Sanctum.
/// It is intentionally layered rather than a single flat background so the
/// chamber feels inhabited even when the app has no active data to show.
struct MercurySanctumBackdrop: View {
    let accent: Color

    var body: some View {
        ZStack {
            MercuryVisualTokens.void
            RadialGradient(colors: [accent.opacity(0.08), .clear], center: .center, startRadius: 24, endRadius: 300)
            RadialGradient(colors: [MercuryVisualTokens.sanctumPurple.opacity(0.14), .clear], center: UnitPoint(x: 0.20, y: 0.22), startRadius: 10, endRadius: 280)
            MercuryAmbientField(state: .idle, accent: accent)

            Canvas { context, size in
                let seed: [CGPoint] = [
                    .init(x: 0.08, y: 0.16), .init(x: 0.82, y: 0.14),
                    .init(x: 0.18, y: 0.38), .init(x: 0.90, y: 0.44),
                    .init(x: 0.10, y: 0.70), .init(x: 0.78, y: 0.76),
                    .init(x: 0.42, y: 0.58), .init(x: 0.58, y: 0.24)
                ]
                for point in seed {
                    let center = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    let rect = CGRect(x: center.x, y: center.y, width: 1.5, height: 1.5)
                    context.fill(Path(ellipseIn: rect), with: .color(MercuryVisualTokens.silver.opacity(0.16)))
                }
            }
            .blendMode(.screen)
        }
        .drawingGroup(opaque: true)
        .allowsHitTesting(false)
    }
}

/// Living core used as Mercury's persistent visual signature.
/// The visual state now directly controls material energy and deformation.
struct MercuryPresenceOrb: View {
    let accent: Color
    var size: CGFloat = 132
    var state: VisualState = .idle

    var body: some View {
        MercuryLivingMaterial(state: state, size: size, accent: accent)
            .frame(width: size * 2, height: size * 2)
    }
}

struct MercuryGlassSurface<Content: View>: View {
    let accent: Color
    let content: Content

    init(accent: Color, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: MercuryVisualTokens.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MercuryVisualTokens.cornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            }
    }
}

struct MercuryRealmPill: View {
    let title: String
    let subtitle: String
    let accent: Color
    let active: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(active ? accent : accent.opacity(0.24)).frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(active ? accent : MercuryVisualTokens.silver)
                Text(subtitle).font(.caption2).foregroundStyle(MercuryVisualTokens.silver.opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(active ? 0.52 : 0.25), in: Capsule())
        .overlay { Capsule().stroke(accent.opacity(active ? 0.30 : 0.10), lineWidth: 1) }
    }
}
