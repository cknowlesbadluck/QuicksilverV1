import SwiftUI

/// Procedural Mercury material built from SwiftUI Canvas primitives.
///
/// This is intentionally structured as a material stack rather than a single
/// decorative effect so the visual language can later be mapped to a native
/// shader without changing the state model or call sites.
struct MercuryLivingMaterial: View {
    let state: VisualState
    let size: CGFloat
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 : 1.0 / 30.0,
                paused: reduceMotion
            )
        ) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let phase = time / 3.6
            let energy = state.ambientEnergy
            let brightness = state.coreBrightness
            let distortion = 0.012 + (energy * 0.028)
            let pulse = 0.5 + (0.5 * sin(phase * .pi * 2.0))

            ZStack {
                Circle()
                    .fill(accent.opacity(0.035 + (energy * 0.035)))
                    .frame(width: size * (1.95 + CGFloat(pulse * 0.08)))
                    .blur(radius: size * 0.16)

                Circle()
                    .fill(accent.opacity(0.055 + (energy * 0.045)))
                    .frame(width: size * 1.55)
                    .blur(radius: size * 0.08)

                MercurySurfaceCanvas(
                    time: time,
                    energy: energy,
                    brightness: brightness,
                    distortion: distortion,
                    accent: accent,
                    size: size
                )
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(0.18 + (energy * 0.08)),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: accent.opacity(0.18 + (energy * 0.12)),
                    radius: size * (0.12 + energy * 0.08)
                )
            }
        }
        .frame(width: size * 2, height: size * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mercury")
        .accessibilityValue(state.rawValue)
    }
}

private struct MercurySurfaceCanvas: View {
    let time: TimeInterval
    let energy: Double
    let brightness: Double
    let distortion: Double
    let accent: Color
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(
                x: canvasSize.width / 2,
                y: canvasSize.height / 2
            )
            let radius = min(canvasSize.width, canvasSize.height) / 2
            let orbitPhase = time * (0.22 + energy * 0.20)

            let base = Path(
                ellipseIn: CGRect(
                    x: 0,
                    y: 0,
                    width: canvasSize.width,
                    height: canvasSize.height
                )
            )
            context.fill(
                base,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: .white.opacity(0.96), location: 0.00),
                        .init(
                            color: accent.opacity(0.78 * brightness),
                            location: 0.20
                        ),
                        .init(
                            color: Color(red: 0.16, green: 0.10, blue: 0.20),
                            location: 0.58
                        ),
                        .init(
                            color: Color(red: 0.015, green: 0.012, blue: 0.025),
                            location: 1.00
                        )
                    ]),
                    center: CGPoint(
                        x: 0.38 * canvasSize.width,
                        y: 0.30 * canvasSize.height
                    ),
                    startRadius: 2,
                    endRadius: radius * 1.12
                )
            )

            for index in 0..<7 {
                let normalized = CGFloat(index + 1) / 8.0
                let wave = sin(
                    (time * (0.34 + energy * 0.42))
                        + Double(index) * 1.31
                )
                let offset = CGFloat(wave) * radius * distortion
                let rect = CGRect(
                    x: center.x - radius * normalized + offset,
                    y: center.y - radius * normalized,
                    width: radius * 2 * normalized,
                    height: radius * 2 * normalized
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.025 + (energy * 0.018))),
                    lineWidth: max(0.6, radius * 0.008)
                )
            }

            for index in 0..<4 {
                let angle = orbitPhase + (Double(index) * (.pi / 2.0))
                let length = radius * (0.62 + (energy * 0.16))
                let start = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius * 0.12,
                    y: center.y + CGFloat(sin(angle)) * radius * 0.12
                )
                let end = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * length,
                    y: center.y + CGFloat(sin(angle)) * length
                )
                var line = Path()
                line.move(to: start)
                line.addLine(to: end)
                context.stroke(
                    line,
                    with: .color(
                        index.isMultiple(of: 2)
                            ? accent.opacity(0.16)
                            : .white.opacity(0.10)
                    ),
                    lineWidth: radius * 0.035
                )
            }

            if energy > 0.45 {
                let coreRadius = radius * (0.10 + (energy * 0.075))
                let core = CGRect(
                    x: center.x - coreRadius,
                    y: center.y - coreRadius,
                    width: coreRadius * 2,
                    height: coreRadius * 2
                )
                context.fill(
                    Path(ellipseIn: core),
                    with: .radialGradient(
                        Gradient(
                            colors: [
                                .white.opacity(0.92),
                                accent.opacity(0.62),
                                .clear
                            ]
                        ),
                        center: center,
                        startRadius: 0,
                        endRadius: coreRadius
                    )
                )
            }
        }
        .drawingGroup()
    }
}

struct MercuryAmbientField: View {
    let state: VisualState
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: reduceMotion ? 1.0 : 1.0 / 20.0,
                paused: reduceMotion
            )
        ) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let energy = state.ambientEnergy

            Canvas { context, size in
                let center = CGPoint(
                    x: size.width / 2,
                    y: size.height / 2
                )
                let baseRadius = min(size.width, size.height) * 0.34

                for index in 0..<5 {
                    let phase = time * (0.08 + Double(index) * 0.018)
                    let x = center.x
                        + CGFloat(sin(phase + Double(index))) * size.width * 0.22
                    let y = center.y
                        + CGFloat(cos(phase * 0.83 + Double(index))) * size.height * 0.18
                    let radius = baseRadius * (0.65 + CGFloat(index) * 0.11)
                    let rect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            accent.opacity(
                                (0.012 + energy * 0.012)
                                    / Double(index + 1)
                            )
                        )
                    )
                }
            }
            .blur(radius: 24)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }
}
