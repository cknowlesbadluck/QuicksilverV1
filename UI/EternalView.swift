import SwiftUI
import Core
import Personas
import Nexus

/// The Eternal Observatory — observation, diagnostics, memory, long-term patterns.
/// Its visual language is Living Mercury under Controlled Chaos.
struct EternalView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: EternalViewModel?
    @State private var observationDraft = ""
    @State private var askDraft = ""
    @State private var lastAnswer: String?
    @State private var isAsking = false

    var body: some View {
        Group {
            if let viewModel {
                eternalContent(viewModel)
            } else {
                PersonaTheme.voidBlack
                    .ignoresSafeArea()
                    .overlay { ProgressView().tint(PersonaTheme.glowPurple) }
                    .onAppear { viewModel = EternalViewModel(container: container) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func eternalContent(_ vm: EternalViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)
        let spacing = 18 * PersonaTheme.density(for: personaID)

        return ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()
            AmbientLayer(personaID: "eternal", visualState: vm.isAwake ? .elevated : .idle)
            ObservatoryField(intensity: vm.isAwake ? 1 : 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    realmHeader(vm, accent: accent, radius: radius)
                    if !vm.isAwake { awakenCard(vm, accent: accent, radius: radius) }
                    signalsRow(vm, radius: radius)
                    if let insight = vm.latestInsight {
                        insightCard(insight, accent: accent, radius: radius)
                    }
                    observationCapture(vm, accent: accent, radius: radius)
                    if !vm.observations.isEmpty { observationsList(vm, radius: radius) }
                    reflectiveAsk(vm, accent: accent, radius: radius)
                    if let answer = lastAnswer {
                        answerCard(answer, accent: accent, radius: radius)
                    }
                    Spacer(minLength: 48)
                }
                .padding(20)
            }
        }
        .navigationTitle("Eternal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(PersonaTheme.spring(for: personaID), value: vm.isAwake)
        .animation(PersonaTheme.spring(for: personaID), value: vm.observations.count)
    }

    private func realmHeader(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 14) {
            ObservatoryLens(accent: accent, active: vm.isAwake)
            VStack(alignment: .leading, spacing: 4) {
                Text("THE ETERNAL")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(PersonaTheme.mercurySilver)
                Text(vm.livingStatus)
                    .font(.subheadline)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.82))
                    .lineLimit(2)
            }
            Spacer()
            Text(vm.isAwake ? "OBSERVING" : "QUIESCENT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(vm.isAwake ? accent : .secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.52), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1)
        }
    }

    private func awakenCard(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mercury is listening.")
                .font(.headline)
                .foregroundStyle(PersonaTheme.mercurySilver)
            Text("Awaken the observational field: patterns, continuity, diagnostics, memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task { await vm.awakenEternal() }
            } label: {
                Text("Awaken Eternal")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accent.opacity(0.18))
                    .foregroundStyle(accent)
                    .clipShape(RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        }
    }

    private func signalsRow(_ vm: EternalViewModel, radius: CGFloat) -> some View {
        HStack(spacing: 8) {
            signalTile("Battery", vm.batteryLevelText, radius)
            signalTile("Network", vm.networkStatus, radius)
            signalTile("Thermal", vm.thermalState, radius)
            signalTile("Health", "\(vm.overallHealthScore)", radius)
        }
    }

    private func signalTile(_ title: String, _ value: String, _ radius: CGFloat) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PersonaTheme.mercurySilver)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: max(8, radius - 4), style: .continuous))
    }

    private func insightCard(_ insight: Insight, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LATEST INSIGHT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(insight.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver)
            if !insight.body.isEmpty {
                Text(insight.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        }
    }

    private func observationCapture(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OBSERVE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PersonaTheme.glowPurple)
            HStack(spacing: 10) {
                TextField("Pattern, continuity note, long-horizon signal…", text: $observationDraft)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.ultraThinMaterial.opacity(0.38), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous))
                    .foregroundStyle(PersonaTheme.mercurySilver)
                Button {
                    let text = observationDraft
                    observationDraft = ""
                    Task { await vm.captureObservation(text) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .disabled(observationDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func observationsList(_ vm: EternalViewModel, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION OBSERVATIONS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            ForEach(Array(vm.observations.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial.opacity(0.25), in: RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous))
            }
        }
    }

    private func reflectiveAsk(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASK THE ETERNAL")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PersonaTheme.toxicGreen)
            TextField("Pattern, history, continuity, diagnose…", text: $askDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(12)
                .background(.ultraThinMaterial.opacity(0.38), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous))
                .foregroundStyle(PersonaTheme.mercurySilver)
            Button {
                let query = askDraft
                askDraft = ""
                isAsking = true
                lastAnswer = nil
                Task {
                    let answer = await vm.askEternal(query)
                    lastAnswer = answer
                    isAsking = false
                }
            } label: {
                HStack {
                    if isAsking {
                        ProgressView().tint(PersonaTheme.voidBlack).scaleEffect(0.8)
                    }
                    Text(isAsking ? "Observing…" : "Observe")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(accent)
                .foregroundStyle(PersonaTheme.voidBlack)
                .clipShape(RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isAsking || askDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func answerCard(_ answer: String, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESPONSE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.32), lineWidth: 1)
        }
    }
}

private struct ObservatoryLens: View {
    let accent: Color
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let angle = reduceMotion ? 0 : time * (active ? 0.32 : 0.08)
            lensContent(angle: angle)
        }
        .frame(width: 42, height: 42)
    }

    @ViewBuilder
    private func lensContent(angle: Double) -> some View {
        ZStack {
            Circle().stroke(accent.opacity(0.28), lineWidth: 1)
            Circle().stroke(PersonaTheme.mercurySilver.opacity(0.5), lineWidth: 2).padding(6)
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
}

private struct ObservatoryField: View {
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.22)
                let accent = PersonaTheme.glowPurple
                for ring in 0..<5 {
                    let radius = min(size.width, size.height) * (0.16 + Double(ring) * 0.10)
                    var path = Path()
                    let steps = 40
                    for step in 0...steps {
                        let angle = Double(step) / Double(steps) * .pi * 2
                        let drift = reduceMotion
                            ? 0
                            : sin(time * 0.12 + angle * 3 + Double(ring)) * (2 + Double(ring))
                        let point = CGPoint(
                            x: center.x + cos(angle) * radius + drift,
                            y: center.y + sin(angle) * radius * 0.42
                        )
                        if step == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    context.stroke(
                        path,
                        with: .color(accent.opacity(0.035 + intensity * 0.025)),
                        lineWidth: 0.8
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
