import SwiftUI
import Core

/// The Quicksilver core — living entity, not icon.
/// Liquid mercury + dark glass + cosmic energy + intelligence.
/// Internal motion is layered and semi-independent.
struct QuicksilverCoreView: View {
    let personaID: String
    let chamber: SanctumChamber
    let visualState: VisualState
    var size: CGFloat = 88

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breath: CGFloat = 1.0
    @State private var fluidPhase: Double = 0
    @State private var orbit: Double = 0
    @State private var turbulence: CGFloat = 0
    @State private var haloScale: CGFloat = 1.0

    private var accent: Color { PersonaTheme.accent(for: personaID) }
    private var brightness: Double { visualState.coreBrightness }

    var body: some View {
        ZStack {
            // Outer atmospheric halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.22 * brightness),
                            accent.opacity(0.06 * brightness),
                            .clear
                        ],
                        center: .center,
                        startRadius: size * 0.15,
                        endRadius: size * 1.15
                    )
                )
                .frame(width: size * 2.4, height: size * 2.4)
                .scaleEffect(haloScale)

            // Secondary energy ring (thinking / processing)
            if visualState.isElevated {
                Circle()
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: 1.2, dash: [3, 7])
                    )
                    .foregroundStyle(accent.opacity(0.45 * brightness))
                    .frame(width: size * 1.55, height: size * 1.55)
                    .rotationEffect(.degrees(orbit))
            }

            // Glyph orbit ring
            Circle()
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 0.8, dash: [2, 10])
                )
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.28 * brightness))
                .frame(width: size * 1.35, height: size * 1.35)
                .rotationEffect(.degrees(-orbit * 0.6))

            // Dark glass shell
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            PersonaTheme.voidBlack.opacity(0.2),
                            PersonaTheme.voidBlack.opacity(0.65)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size * 1.08, height: size * 1.08)

            // Liquid mercury core — layered gradients shift with phase
            Circle()
                .fill(
                    AngularGradient(
                        colors: coreColors,
                        center: .center,
                        angle: .degrees(fluidPhase)
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    // Internal highlight (specular)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.35 * brightness),
                                    Color.white.opacity(0.05),
                                    .clear
                                ],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: size * 0.45
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            PersonaTheme.mercurySilver.opacity(0.35 * brightness),
                            lineWidth: 1
                        )
                )
                .shadow(color: accent.opacity(0.45 * brightness), radius: 18 * brightness)
                .scaleEffect(breath)
                .offset(x: turbulence * 0.6, y: turbulence * -0.4)

            // Micro-particles near core when elevated
            if visualState.isElevated && !reduceMotion {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(accent.opacity(0.5))
                        .frame(width: 2.5, height: 2.5)
                        .offset(particleOffset(index: index))
                }
            }
        }
        .frame(width: size * 2.5, height: size * 2.5)
        .onAppear { startMotion() }
        .onChange(of: visualState) { _, _ in startMotion() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Palette

    private var coreColors: [Color] {
        let base = [
            PersonaTheme.mercurySilver.opacity(0.95),
            accent.opacity(0.85),
            PersonaTheme.liquidMetal,
            accent.opacity(0.7),
            PersonaTheme.mercurySilver.opacity(0.9)
        ]
        return base
    }

    // MARK: - Motion

    private func startMotion() {
        guard !reduceMotion else {
            breath = 1.0
            haloScale = 1.0
            turbulence = 0
            return
        }

        // Breath — slower when idle / sleeping
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

        withAnimation(.linear(duration: visualState.isElevated ? 6 : 14).repeatForever(autoreverses: false)) {
            fluidPhase = 360
        }

        // Subtle turbulence only when elevated — personality, not noise
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

    private func particleOffset(index: Int) -> CGSize {
        let angle = (Double(index) / 5.0) * .pi * 2 + orbit * .pi / 180
        let radius = size * 0.72
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }

    private var accessibilityLabel: String {
        "Quicksilver core, \(visualState.rawValue), \(chamber.displayName)"
    }
}
