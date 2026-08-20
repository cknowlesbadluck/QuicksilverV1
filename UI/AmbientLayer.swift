import SwiftUI
import Core

/// Living environment for the Sanctum.
/// Controlled chaos is persistent but bounded: particles, traces and a slow
/// atmospheric field orbit the same invisible center as the mercury core.
struct AmbientLayer: View {
    let personaID: String
    var visualState: VisualState = .idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var intensity: Double {
        PersonaTheme.ambientIntensity(for: personaID) * visualState.ambientEnergy
    }

    var body: some View {
        let accent = PersonaTheme.accent(for: personaID)
        let secondary = PersonaTheme.secondaryAccent(for: personaID)
        let baseCount = Int(10 + intensity * 20)
        let particleCount = reduceMotion
            ? max(4, baseCount / 3)
            : Int(Double(baseCount) * visualState.particleMultiplier)

        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.42)

                // Stable particle seeds make the chaos feel like a persistent environment.
                for index in 0..<particleCount {
                    let seed = Double(index) * 1.37
                    let angle = seed * 2.399963 + time * (0.012 + intensity * 0.025)
                    let orbit = min(size.width, size.height) * (0.24 + 0.06 * sin(seed * 1.73))
                    let xPos = center.x + cos(angle) * orbit * (0.85 + 0.12 * sin(seed))
                    let yPos = center.y + sin(angle * 1.13) * orbit * 1.7
                    let radius = 1.0 + intensity * 1.5
                    let opacity = 0.035 + 0.09 * intensity + 0.025 * sin(time * 0.35 + seed)
                    let color = index.isMultiple(of: 4) ? secondary : accent

                    context.fill(
                        Path(ellipseIn: CGRect(x: xPos - radius, y: yPos - radius, width: radius * 2, height: radius * 2)),
                        with: .color(color.opacity(opacity))
                    )
                }

                // Broken traces: deliberately incomplete orbital geometry.
                let traceCount = visualState.isElevated ? 7 : 4
                for index in 0..<traceCount {
                    let seed = Double(index)
                    let radius = min(size.width, size.height) * (0.20 + seed * 0.045)
                    var path = Path()
                    let segments = 18

                    for segment in 0..<segments {
                        let t = Double(segment) / Double(segments - 1)
                        let angle = -1.05 + t * 2.10 + time * (0.006 + intensity * 0.008)
                        let wobble = sin(angle * 3.0 + seed + time * 0.12) * 5.0 * intensity
                        let point = CGPoint(
                            x: center.x + cos(angle) * (radius + wobble),
                            y: center.y + sin(angle) * (radius + wobble) * 0.52
                        )
                        if segment == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }

                    context.stroke(
                        path,
                        with: .color((index.isMultiple(of: 3) ? secondary : PersonaTheme.mercurySilver).opacity(0.018 + intensity * 0.035)),
                        style: StrokeStyle(lineWidth: 0.65, lineCap: .round, dash: [18, 28])
                    )
                }

                // Atmospheric bloom ties the environment to the living core.
                let glowRadius = min(size.width, size.height) * (0.20 + intensity * 0.14)
                let glowRect = CGRect(
                    x: center.x - glowRadius,
                    y: center.y - glowRadius * 0.62,
                    width: glowRadius * 2,
                    height: glowRadius * 1.24
                )
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            accent.opacity(0.075 * intensity * visualState.coreBrightness),
                            secondary.opacity(0.025 * intensity),
                            .clear
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: glowRadius
                    )
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .animation(MotionTokens.environmentalWake, value: personaID)
        .animation(MotionTokens.stabilization, value: visualState)
    }
}
