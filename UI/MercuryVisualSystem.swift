import SwiftUI

/// Mercury visual system views (Sanctum backdrop, presence orb, glass surface, realm pill).
/// Colour and geometry come from `PersonaTheme`; durations from `MotionTokens`.

/// Atmospheric foundation for the Sanctum.
/// It is intentionally layered rather than a single flat background so the
/// chamber feels inhabited even when the app has no active data to show.
struct MercurySanctumBackdrop: View {
    let accent: Color

    var body: some View {
        ZStack {
            PersonaTheme.voidBlack

            RadialGradient(
                colors: [accent.opacity(0.20), PersonaTheme.voidBlack.opacity(0)],
                center: .center,
                startRadius: 24,
                endRadius: 270
            )

            RadialGradient(
                colors: [PersonaTheme.sanctumPurple.opacity(0.18), .clear],
                center: UnitPoint(x: 0.20, y: 0.22),
                startRadius: 10,
                endRadius: 260
            )

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
                    context.fill(Path(ellipseIn: rect), with: .color(PersonaTheme.mercurySilver.opacity(0.22)))
                }
            }
            .blendMode(.screen)
        }
        .drawingGroup(opaque: true)
        .allowsHitTesting(false)
    }
}

/// Living core used as Mercury's persistent visual signature.
/// TimelineView keeps the pulse independent from the view's local state and
/// avoids manually scheduling timers in the UI layer.
struct MercuryPresenceOrb: View {
    let accent: Color
    var size: CGFloat = 132

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate / MotionTokens.corePulseDuration
            let pulse = 0.5 + 0.5 * sin(phase * .pi * 2.0)
            let scale = 0.96 + (0.045 * pulse)
            let opacity = 0.58 + (0.20 * pulse)

            ZStack {
                Circle()
                    .fill(accent.opacity(0.055))
                    .frame(width: size * 1.72, height: size * 1.72)

                Circle()
                    .fill(accent.opacity(0.09))
                    .frame(width: size * 1.42, height: size * 1.42)

                Circle()
                    .stroke(accent.opacity(0.25), lineWidth: 1)
                    .frame(width: size * 1.30, height: size * 1.30)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white.opacity(0.92),
                                accent.opacity(opacity),
                                PersonaTheme.quicksilverDeep.opacity(0.72),
                                .clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .stroke(accent.opacity(0.42), lineWidth: 1)
                    }
                    .scaleEffect(scale)
            }
        }
        .frame(width: size * 1.72, height: size * 1.72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quicksilver core")
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
            .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: PersonaTheme.glassCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PersonaTheme.glassCornerRadius, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
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
            Circle()
                .fill(active ? accent : accent.opacity(0.24))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(active ? accent : PersonaTheme.mercurySilver)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(active ? 0.52 : 0.25), in: Capsule())
        .overlay {
            Capsule()
                .stroke(accent.opacity(active ? 0.34 : 0.12), lineWidth: 1)
        }
    }
}
