import SwiftUI
import Core

/// Subtle living environment of the Sanctum.
/// Particles, mercury flow, slow celestial motion.
/// Intensity and palette respond to chamber + VisualState.
struct AmbientLayer: View {
    let personaID: String
    let chamber: SanctumChamber
    var visualState: VisualState = .idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let accent = PersonaTheme.accent(for: personaID)
        let intensity = chamber.ambientIntensity * visualState.ambientEnergy
        let baseCount = Int(10 + intensity * 20)
        let particleCount = reduceMotion
            ? max(4, baseCount / 3)
            : Int(Double(baseCount) * visualState.particleMultiplier)

        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Chamber-reactive drifting particles
                for idx in 0..<particleCount {
                    let seed = Double(idx) * 1.37
                    let speed = 0.04 + intensity * 0.07
                    let x = (sin(time * speed + seed) * 0.42 + 0.5) * size.width
                    let y = (cos(time * (speed * 0.75) + seed * 1.3) * 0.42 + 0.5) * size.height
                    let baseOpacity = 0.04 + 0.10 * intensity
                    let opacity = baseOpacity + 0.04 * sin(time * 0.35 + seed)
                    let radius = 1.4 + intensity * 1.6

                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(accent.opacity(opacity))
                    )
                }

                // Mercury sheen lines — denser in Forge / elevated states
                let lineCount = (chamber == .forge || visualState.isElevated) ? 6 : 3
                let lineOpacity = 0.02 + intensity * 0.045
                for idx in 0..<lineCount {
                    let y = size.height * (0.15 + Double(idx) * (0.7 / Double(max(lineCount, 1))))
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y + sin(time * 0.4 + Double(idx)) * 8 * intensity))
                    path.addLine(to: CGPoint(x: size.width, y: y + cos(time * 0.35 + Double(idx)) * 8 * intensity))
                    context.stroke(
                        path,
                        with: .color(PersonaTheme.mercurySilver.opacity(lineOpacity)),
                        lineWidth: chamber == .forge ? 1.2 : 0.9
                    )
                }

                // Soft central glow when a chamber is awake or state is elevated
                if chamber != .sanctum || visualState.isElevated {
                    let glowRadius = min(size.width, size.height) * (0.20 + intensity * 0.14)
                    let glowRect = CGRect(
                        x: size.width * 0.5 - glowRadius,
                        y: size.height * 0.38 - glowRadius * 0.6,
                        width: glowRadius * 2,
                        height: glowRadius * 1.4
                    )
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                accent.opacity(0.06 * intensity * visualState.coreBrightness),
                                accent.opacity(0)
                            ]),
                            center: CGPoint(x: size.width * 0.5, y: size.height * 0.38),
                            startRadius: 0,
                            endRadius: glowRadius
                        )
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(MotionTokens.environmentalWake, value: chamber)
        .animation(MotionTokens.stabilization, value: visualState)
    }
}
