import SwiftUI
import Core
import Personas
import Nexus

/// The Forge — creation, engineering, architecture, experiments.
/// A functional realm, not a concept. All decisions route through MercuryBrain.
struct ForgeView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: ForgeViewModel?
    @State private var noteDraft: String = ""
    @State private var askDraft: String = ""
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

    @ViewBuilder
    private func forgeContent(_ vm: ForgeViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)
        let spacing = 16 * PersonaTheme.density(for: personaID)

        ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()

            AmbientLayer(personaID: personaID, chamber: .forge)

            ScrollView {
                VStack(alignment: .leading, spacing: spacing) {
                    header(vm, accent: accent, radius: radius)

                    if !vm.isAwake {
                        awakenCard(vm, accent: accent, radius: radius)
                    }

                    signalsRow(vm, radius: radius)

                    if let insight = vm.latestInsight {
                        insightCard(insight, accent: accent, radius: radius)
                    }

                    noteCapture(vm, accent: accent, radius: radius)

                    if !vm.sessionNotes.isEmpty {
                        notesList(vm, radius: radius)
                    }

                    constructiveAsk(vm, accent: accent, radius: radius)

                    if let answer = lastAnswer {
                        answerCard(answer, accent: accent, radius: radius)
                    }

                    Spacer(minLength: 40)
                }
                .padding(20)
            }
        }
        .navigationTitle("Forge")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
        .onDisappear {
            vm.stopLiveRefresh()
        }
        .animation(PersonaTheme.spring(for: personaID), value: vm.isAwake)
        .animation(PersonaTheme.spring(for: personaID), value: vm.sessionNotes.count)
    }

    // MARK: - Header

    private func header(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 10, height: 10)
                    .shadow(color: accent.opacity(0.7), radius: 6)

                Text("THE FORGE")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(PersonaTheme.mercurySilver)

                Spacer()

                Text(vm.isAwake ? "AWAKE" : "DORMANT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(vm.isAwake ? PersonaTheme.toxicGreen : .secondary)
            }

            Text(vm.livingStatus)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9))
                .lineLimit(2)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(PersonaTheme.radioactiveStroke(for: "forge"), lineWidth: 1)
        )
    }

    // MARK: - Awaken

    private func awakenCard(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Forge is dormant")
                .font(.headline)
                .foregroundStyle(PersonaTheme.mercurySilver)
            Text("Awaken to shift Mercury into constructive mode. Architecture, Swift, experiments.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                Task { await vm.awakenForge() }
            } label: {
                Text("Awaken Forge")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(accent.opacity(0.2))
                    .foregroundStyle(accent)
                    .clipShape(RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Signals

    private func signalsRow(_ vm: ForgeViewModel, radius: CGFloat) -> some View {
        HStack(spacing: 10) {
            signalTile("Battery", vm.batteryLevelText, radius: radius)
            signalTile("Network", vm.networkStatus, radius: radius)
            signalTile("Thermal", vm.thermalState, radius: radius)
            signalTile("Health", "\(vm.overallHealthScore)", radius: radius)
        }
    }

    private func signalTile(_ title: String, _ value: String, radius: CGFloat) -> some View {
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
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: max(8, radius - 4), style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
    }

    // MARK: - Insight

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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Note Capture

    private func noteCapture(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPTURE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PersonaTheme.toxicGreen)

            HStack(spacing: 10) {
                TextField("Architecture note, decision, experiment…", text: $noteDraft)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.5))
                    )
                    .foregroundStyle(PersonaTheme.mercurySilver)

                Button {
                    let text = noteDraft
                    noteDraft = ""
                    Task { await vm.captureNote(text) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .disabled(noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func notesList(_ vm: ForgeViewModel, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION NOTES")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(Array(vm.sessionNotes.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(0.3))
                    )
            }
        }
    }

    // MARK: - Constructive Ask

    private func constructiveAsk(_ vm: ForgeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASK THE FORGE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PersonaTheme.glowPurple)

            TextField("Implement, refactor, debug, structure…", text: $askDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.5))
                )
                .foregroundStyle(PersonaTheme.mercurySilver)

            Button {
                let query = askDraft
                askDraft = ""
                isAsking = true
                lastAnswer = nil
                Task {
                    let answer = await vm.askForge(query)
                    lastAnswer = answer
                    isAsking = false
                }
            } label: {
                HStack {
                    if isAsking {
                        ProgressView()
                            .tint(PersonaTheme.voidBlack)
                            .scaleEffect(0.8)
                    }
                    Text(isAsking ? "Forging…" : "Forge")
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(PersonaTheme.radioactiveStroke(for: "forge", intensity: 0.8), lineWidth: 1)
        )
    }
}
