import SwiftUI

// MARK: - Observatory visuals
// Moved from EternalView.swift; internal (was file-private) so EternalView can use them across files.

struct ObservatoryLens: View {
    let accent: Color
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 8.0 : 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let angle = reduceMotion ? 0.0 : t * (active ? 0.32 : 0.08)
            ZStack {
                Circle().stroke(accent.opacity(0.28), lineWidth: 1)
                Circle()
                    .stroke(PersonaTheme.mercurySilver.opacity(0.5), lineWidth: 2)
                    .padding(6)
                Circle()
                    .fill(
                        .radialGradient(
                            colors: [
                                PersonaTheme.mercurySilver.opacity(0.8),
                                accent.opacity(0.25),
                                .clear
                            ],
                            center: .center,
                            startRadius: 1,
                            endRadius: 20
                        )
                    )
                    .padding(9)
                Rectangle()
                    .fill(accent.opacity(0.7))
                    .frame(width: 1, height: 30)
                    .rotationEffect(.radians(angle))
            }
        }
        .frame(width: 42, height: 42)
    }
}

struct ObservatoryField: View {
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 8.0 : 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                drawRings(context: context, size: size, time: t)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawRings(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.22)
        let accent = PersonaTheme.glowPurple
        let steps = 24

        for ring in 0..<4 {
            let radius = min(size.width, size.height) * (0.16 + Double(ring) * 0.10)
            var path = Path()
            for step in 0...steps {
                let a = Double(step) / Double(steps) * .pi * 2
                let drift: Double
                if reduceMotion {
                    drift = 0
                } else {
                    drift = sin(time * 0.12 + a * 3 + Double(ring)) * (2 + Double(ring))
                }
                let p = CGPoint(
                    x: center.x + cos(a) * radius + drift,
                    y: center.y + sin(a) * radius * 0.42
                )
                if step == 0 {
                    path.move(to: p)
                } else {
                    path.addLine(to: p)
                }
            }
            let opacity = 0.035 + intensity * 0.025
            context.stroke(path, with: .color(accent.opacity(opacity)), lineWidth: 0.8)
        }
    }
}
