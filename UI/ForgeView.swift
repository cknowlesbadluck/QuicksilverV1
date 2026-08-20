import SwiftUI
import Core
import Personas
import Nexus

/// The Forge — creation, engineering, architecture, experiments.
/// Its visual language is Living Mercury under Controlled Chaos.
struct ForgeView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: ForgeViewModel?
    @State private var noteDraft = ""
    @State private var askDraft = ""
    @State private var lastAnswer: String?
    @State private var isAsking = false

    var body: some View {
        Group {
            if let viewModel {
                forgeContent(viewModel)
            } else {
                PersonaTheme.voidBlack.ignoresSafeArea()
                    .overlay { ProgressView().tint(PersonaTheme.toxicGreen) }
                    .onAppear { viewModel = ForgeViewModel(container: container) }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func forgeContent(_ vm: ForgeViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)
        let spacing = 16 * PersonaTheme.density(for: personaID)

        return ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()
            AmbientLayer(personaID: "forge", visualState: vm.isAwake ? .elevated : .idle)
            MercuryRealmBackdrop(personaID: "forge", intensity: vm.isAwake ? 1 : 0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    realmHeader(vm, accent: accent, radius: radius)
                    if !vm.isAwake { awakenCard(vm, accent: accent, radius: radius) }
                    signalsRow(vm, radius: radius)
                    if let insight = vm.latestInsight { insightCard(insight, accent: accent, radius: radius) }
                    noteCapture(vm, accent: accent, radius: radius)
                    if !vm.sessionNotes.isEmpty { notesList(vm, radius: radius) }
                    constructiveAsk(vm, accent: accent, radius: radius)
                    if let answer = lastAnswer { answerCard(answer, accent: accent, radius: radius) }
                    Spacer(minLength: 48)
                }
                .padding(20)
            }
        }
        .navigationTitle("Forge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.refresh(); vm.startLiveRefresh() }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(PersonaTheme.spring(for: personaID), value: vm.isAwake)
        .animation(PersonaTheme.spring(for: personaID), value: vm.sessionNotes.count)
    }

    private func realmHeader(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 14) {
            MercuryDroplet(accent: accent, size: 42, active: vm.isAwake)
            VStack(alignment: .leading, spacing: 4) {
                Text("THE FORGE").font(.caption.weight(.bold)).tracking(1.8).foregroundStyle(PersonaTheme.mercurySilver)
                Text(vm.livingStatus).font(.subheadline).foregroundStyle(PersonaTheme.mercurySilver.opacity(0.82)).lineLimit(2)
            }
            Spacer()
            Text(vm.isAwake ? "AWAKE" : "DORMANT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(vm.isAwake ? accent : .secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.52), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(accent.opacity(0.42), lineWidth: 1))
    }

    private func awakenCard(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mercury is waiting to move.").font(.headline).foregroundStyle(PersonaTheme.mercurySilver)
            Text("Awaken the constructive field: architecture, Swift, experiments.").font(.caption).foregroundStyle(.secondary)
            Button { Task { await vm.awakenForge() } } label: {
                Text("Awaken Forge").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(accent.opacity(0.18)).foregroundStyle(accent).clipShape(RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.42), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(accent.opacity(0.28), lineWidth: 1))
    }

    private func signalsRow(_ vm: ForgeViewModel, radius: CGFloat) -> some View {
        HStack(spacing: 8) {
            signalTile("Battery", vm.batteryLevelText, radius)
            signalTile("Network", vm.networkStatus, radius)
            signalTile("Thermal", vm.thermalState, radius)
            signalTile("Health", "\(vm.overallHealthScore)", radius)
        }
    }

    private func signalTile(_ title: String, _ value: String, _ radius: CGFloat) -> some View {
        VStack(spacing: 3) { Text(title.uppercased()).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary); Text(value).font(.caption.weight(.semibold)).foregroundStyle(PersonaTheme.mercurySilver).lineLimit(1) }
            .frame(maxWidth: .infinity).padding(.vertical, 9)
            .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: max(8, radius - 4), style: .continuous))
    }

    private func insightCard(_ insight: Insight, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LATEST INSIGHT").font(.caption2.weight(.bold)).foregroundStyle(accent)
            Text(insight.title).font(.subheadline.weight(.medium)).foregroundStyle(PersonaTheme.mercurySilver)
            if !insight.body.isEmpty { Text(insight.body).font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(accent.opacity(0.24), lineWidth: 1))
    }

    private func noteCapture(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPTURE").font(.caption2.weight(.bold)).foregroundStyle(PersonaTheme.toxicGreen)
            HStack(spacing: 10) {
                TextField("Architecture note, decision, experiment…", text: $noteDraft).textFieldStyle(.plain).padding(12)
                    .background(.ultraThinMaterial.opacity(0.38), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)).foregroundStyle(PersonaTheme.mercurySilver)
                Button { let text = noteDraft; noteDraft = ""; Task { await vm.captureNote(text) } } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(accent) }.buttonStyle(.plain)
                    .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func notesList(_ vm: ForgeViewModel, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION NOTES").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            ForEach(Array(vm.sessionNotes.enumerated()), id: \.offset) { _, note in
                Text(note).font(.caption).foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9)).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial.opacity(0.25), in: RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous))
            }
        }
    }

    private func constructiveAsk(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASK THE FORGE").font(.caption2.weight(.bold)).foregroundStyle(PersonaTheme.glowPurple)
            TextField("Implement, refactor, debug, structure…", text: $askDraft, axis: .vertical).lineLimit(3...6).textFieldStyle(.plain).padding(12)
                .background(.ultraThinMaterial.opacity(0.38), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)).foregroundStyle(PersonaTheme.mercurySilver)
            Button {
                let query = askDraft; askDraft = ""; isAsking = true; lastAnswer = nil
                Task { let answer = await vm.askForge(query); lastAnswer = answer; isAsking = false }
            } label: {
                HStack { if isAsking { ProgressView().tint(PersonaTheme.voidBlack).scaleEffect(0.8) }; Text(isAsking ? "Forging…" : "Forge").font(.subheadline.weight(.semibold)) }
                    .frame(maxWidth: .infinity).padding(.vertical, 12).background(accent).foregroundStyle(PersonaTheme.voidBlack).clipShape(RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
            }.buttonStyle(.plain).disabled(isAsking || askDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func answerCard(_ answer: String, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text("RESPONSE").font(.caption2.weight(.bold)).foregroundStyle(accent); Text(answer).font(.subheadline).foregroundStyle(PersonaTheme.mercurySilver) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(accent.opacity(0.32), lineWidth: 1))
    }
}

private struct MercuryDroplet: View {
    let accent: Color
    let size: CGFloat
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let wobble = reduceMotion ? 0 : sin(t * (active ? 1.7 : 0.5)) * 2.5
            ZStack {
                Circle().fill(.radialGradient(colors: [PersonaTheme.mercurySilver.opacity(0.9), accent.opacity(0.35), .clear], center: .center, startRadius: 1, endRadius: size * 0.7))
                Capsule().fill(.linearGradient(colors: [PersonaTheme.mercurySilver, accent.opacity(0.5), PersonaTheme.voidBlack], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size * 0.52, height: size * 0.72).rotationEffect(.degrees(wobble)).shadow(color: accent.opacity(0.55), radius: active ? 10 : 4)
            }
        }.frame(width: size, height: size)
    }
}

private struct MercuryRealmBackdrop: View {
    let personaID: String
    let intensity: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 / 8 : 1 / 30)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let accent = PersonaTheme.accent(for: personaID)
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.24)
                let maxR = min(size.width, size.height) * 0.5
                for i in 0..<7 {
                    let phase = Double(i) * 0.87
                    let r = maxR * (0.20 + Double(i) * 0.085)
                    let x = center.x + cos(t * (0.04 + Double(i) * 0.006) + phase) * r * 0.32
                    let y = center.y + sin(t * (0.05 + Double(i) * 0.004) + phase) * r * 0.18
                    let rect = CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)
                    context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(0.04 + intensity * 0.035)))
                }
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}
