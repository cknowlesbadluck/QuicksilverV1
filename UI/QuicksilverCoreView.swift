import SwiftUI
import Core

/// The Quicksilver core — living entity, not icon.
/// Liquid mercury + controlled chaos + dark glass + intelligence.
/// Motion is layered: the surface deforms, the field drifts, and the orbital
/// structure keeps the chaos bounded by a recognizable center.
struct QuicksilverCoreView: View {
    let personaID: String
    let visualState: VisualState
    var size: CGFloat = 88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breath: CGFloat = 1.0
    @State private var orbit: Double = 0
    @State private var turbulence: CGFloat = 0
    @State private var haloScale: CGFloat = 1.0

    private var accent: Color { PersonaTheme.accent(for: personaID) }
    private var secondary: Color { PersonaTheme.secondaryAccent(for: personaID) }
    private var brightness: Double { visualState.coreBrightness }

    var body: some View {
        ZStack {
            // Atmospheric bloom — deliberately larger than the object so the
            // mercury feels like it is affecting the surrounding space.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.22 * brightness),
                            secondary.opacity(0.08 * brightness),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.12,
                        endRadius: size * PersonaTheme.chaosCoreBloom
                    )
                )
                .frame(width: size * 2.55, height: size * 2.55)
                .scaleEffect(haloScale)

            // Controlled-chaos field: sparse orbital fragments establish a
            // spatial grammar without becoming decorative noise.
            if !reduceMotion {
                MercuryChaosField(
                    accent: accent,
                    secondary: secondary,
                    size: size,
                    intensity: PersonaTheme.ambientIntensity(for: personaID)
                )
            }

            // The outer rings are intentionally imperfectly timed: they do
            // not lock to the liquid surface, producing the living feeling.
            if visualState.isElevated {
                Circle()
                    .strokeBorder(
                        accent.opacity(0.38 * brightness),
                        style: StrokeStyle(
                            lineWidth: PersonaTheme.chaosTraceLineWidth,
                            dash: [3, 7]
                        )
                    )
                    .frame(width: size * 1.58, height: size * 1.58)
                    .rotationEffect(.degrees(orbit))
            }

            Circle()
                .strokeBorder(
                    PersonaTheme.mercurySilver.opacity(0.25 * brightness),
                    style: StrokeStyle(
                        lineWidth: PersonaTheme.chaosTraceLineWidth,
                        dash: [2, 10]
                    )
                )
                .frame(width: size * 1.36, height: size * 1.36)
                .rotationEffect(.degrees(-orbit * 0.58))

            // Dark inner depth separates the luminous liquid from the field.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PersonaTheme.voidBlack.opacity(0.18),
                            PersonaTheme.chaosBlack.opacity(0.88)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.10, height: size * 1.10)

            MercuryFluidSurface(
                accent: accent,
                secondary: secondary,
                size: size,
                brightness: brightness,
                turbulence: turbulence,
                reducedMotion: reduceMotion
            )
            .scaleEffect(breath)

            // A single hard specular highlight gives the material its metallic
            // read. It moves independently from the fluid deformation.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PersonaTheme.mercuryBright.opacity(0.44 * brightness),
                            PersonaTheme.mercuryBright.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.24
                    )
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .offset(x: -size * 0.18, y: -size * 0.20)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .frame(width: size * 2.55, height: size * 2.55)
        .onAppear { startMotion() }
        .onChange(of: visualState) { _, _ in startMotion() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Quicksilver core, \(visualState.rawValue), \(personaID)")
    }

    private func startMotion() {
        guard !reduceMotion else {
            breath = 1.0
            haloScale = 1.0
            turbulence = 0
            orbit = 0
            return
        }

        let breathDuration: Double
        switch visualState {
        case .sleeping: breathDuration = 5.5
        case .idle: breathDuration = 3.2
        case .listening: breathDuration = 2.4
        case .thinking, .processing: breathDuration = 1.4
        case .speaking: breathDuration = 1.8
        default: breathDuration = 2.6
        }

        withAnimation(.easeInOut(duration: breathDuration).repeatForever(autoreverses: true)) {
            breath = visualState == .sleeping ? 1.02 : (visualState.isElevated ? 1.07 : 1.04)
            haloScale = visualState.isElevated ? 1.12 : 1.05
        }

        withAnimation(.linear(duration: visualState.isElevated ? 18 : 42).repeatForever(autoreverses: false)) {
            orbit = 360
        }

        if visualState.isElevated {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                turbulence = 1.8
            }
        } else {
            withAnimation(.easeOut(duration: 0.6)) {
                turbulence = 0
            }
        }
    }
}

/// A procedural liquid-metal surface. It is not a static gradient: the
/// boundary itself changes, so the core reads as matter rather than an icon.
private struct MercuryFluidSurface: View {
    let accent: Color
    let secondary: Color
    let size: CGFloat
    let brightness: Double
    let turbulence: CGFloat
    let reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reducedMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = time * 0.72
            let motion = reducedMotion ? 0.0 : 1.0

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = size * PersonaTheme.chaosCoreRadius
                let path = mercuryPath(center: center, radius: radius, phase: phase, motion: motion)

                context.addFilter(.blur(radius: 0.35))
                context.fill(
                    path,
                    with: .radialGradient(
                        Gradient(stops: [
                            .init(color: PersonaTheme.mercuryBright.opacity(0.98 * brightness), location: 0),
                            .init(color: PersonaTheme.mercurySilver.opacity(0.98 * brightness), location: 0.22),
                            .init(color: accent.opacity(0.82 * brightness), location: 0.54),
                            .init(color: secondary.opacity(0.68 * brightness), location: 0.78),
                            .init(color: PersonaTheme.mercuryShadow.opacity(0.94), location: 1)
                        ]),
                        center: CGPoint(x: center.x - size * 0.18, y: center.y - size * 0.20),
                        startRadius: size * 0.04,
                        endRadius: size * 1.02
                    )
                )

                // Broken internal reflections. These are intentionally partial
                // so the eye interprets the surface as curved metal.
                var reflection = Path()
                reflection.move(to: CGPoint(x: center.x - size * 0.60, y: center.y - size * 0.04))
                reflection.addCurve(
                    to: CGPoint(x: center.x + size * 0.54, y: center.y + size * 0.08),
                    control1: CGPoint(x: center.x - size * 0.24, y: center.y - size * 0.25),
                    control2: CGPoint(x: center.x + size * 0.12, y: center.y + size * 0.30)
                )
                context.stroke(
                    reflection,
                    with: .color(PersonaTheme.mercuryBright.opacity(0.20 * brightness)),
                    style: StrokeStyle(lineWidth: PersonaTheme.chaosTraceLineWidth, lineCap: .round)
                )
            }
        }
        .frame(width: size * 1.10, height: size * 1.10)
        .offset(x: turbulence * 0.6, y: turbulence * -0.4)
        .shadow(color: accent.opacity(0.44 * brightness), radius: size * 0.18)
        .shadow(color: secondary.opacity(0.18 * brightness), radius: size * 0.32)
    }

    private func mercuryPath(center: CGPoint, radius: CGFloat, phase: Double, motion: Double) -> Path {
        let points = PersonaTheme.chaosSeedCount
        var path = Path()

        for index in 0..<points {
            let fraction = Double(index) / Double(points)
            let angle = fraction * .pi * 2
            let waveA = sin(angle * 3.0 + phase) * radius * 0.055 * motion
            let waveB = sin(angle * 5.0 - phase * 1.37) * radius * 0.032 * motion
            let waveC = cos(angle * 2.0 + phase * 0.61) * radius * 0.025 * motion
            let radiusOffset = waveA + waveB + waveC
            let x = center.x + cos(angle) * (radius + radiusOffset)
            let y = center.y + sin(angle) * (radius + radiusOffset * 0.82)
            let point = CGPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }
}

/// Sparse environmental motion surrounding the core. The field uses stable
/// seeds, so it feels like a persistent place instead of random particle spam.
private struct MercuryChaosField: View {
    let accent: Color
    let secondary: Color
    let size: CGFloat
    let intensity: Double

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = size * PersonaTheme.chaosOrbitalRadius

                for index in 0..<PersonaTheme.chaosSeedCount {
                    let seed = Double(index)
                    let angle = seed * 2.399963 + time * (0.035 + seed * 0.0015)
                    let orbitRadius = radius * (0.72 + 0.18 * sin(seed * 1.73))
                    let x = center.x + cos(angle) * orbitRadius
                    let y = center.y + sin(angle * 1.13) * orbitRadius * 0.78
                    let particle = PersonaTheme.chaosParticleRadius * size * (0.7 + 0.35 * sin(seed + time * 0.8))
                    let rect = CGRect(x: x - particle, y: y - particle, width: particle * 2, height: particle * 2)
                    let color = index.isMultiple(of: 3) ? secondary : accent
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(PersonaTheme.chaosFieldOpacity * intensity)))
                }
            }
        }
        .frame(width: size * 2.3, height: size * 2.3)
        .allowsHitTesting(false)
    }
}
