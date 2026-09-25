import SwiftUI
import Core
import Personas
import Nexus

/// The Observatory — Eternal chamber for observation, continuity, memory, long-horizon patterns.
/// Constellation is real Memory items; intelligence still flows only through MercuryBrain.
struct EternalView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: EternalViewModel?
    @State private var observationDraft = ""
    @State private var askDraft = ""
    @State private var lastAnswer: String?
    @State private var isAsking = false
    @State private var isScanning = false

    var body: some View {
        Group {
            if let viewModel {
                eternalContent(viewModel)
            } else {
                loadingPlaceholder
            }
        }
        .preferredColorScheme(.dark)
    }

    private var loadingPlaceholder: some View {
        PersonaTheme.voidBlack
            .ignoresSafeArea()
            .overlay { ProgressView().tint(PersonaTheme.glowPurple) }
            .onAppear { viewModel = EternalViewModel(container: container) }
    }

    @ViewBuilder
    private func eternalContent(_ vm: EternalViewModel) -> some View {
        let accentID = vm.activeAspect == .eternal ? "eternal" : vm.activePersonaID
        let accent = PersonaTheme.accent(for: accentID)
        let radius = PersonaTheme.cardCornerRadius(for: accentID)
        let spacing = 18 * PersonaTheme.density(for: accentID)
        let visualState: VisualState = vm.isAwake ? .listening : .idle
        let fieldIntensity = vm.isAwake ? 1.0 : 0.5

        ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()
            AmbientLayer(personaID: "eternal", visualState: visualState)
            ObservatoryField(intensity: fieldIntensity)
            scrollContent(vm, accent: accent, radius: radius, spacing: spacing)
        }
        .navigationTitle("Observatory")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(PersonaTheme.spring(for: accentID), value: vm.isAwake)
        .animation(PersonaTheme.spring(for: accentID), value: vm.observations.count)
        .animation(PersonaTheme.spring(for: accentID), value: vm.constellation.count)
    }

    @ViewBuilder
    private func scrollContent(
        _ vm: EternalViewModel,
        accent: Color,
        radius: CGFloat,
        spacing: CGFloat
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                ObservatoryHeader(isAwake: vm.isAwake, livingStatus: vm.livingStatus, accent: accent, radius: radius)
                if !vm.isAwake {
                    awakenCard(vm, accent: accent, radius: radius)
                }
                ObservatorySignalsRow(
                    batteryLevelText: vm.batteryLevelText,
                    networkStatus: vm.networkStatus,
                    thermalState: vm.thermalState,
                    overallHealthScore: vm.overallHealthScore,
                    radius: radius
                )
                constellationPanel(vm, accent: accent, radius: radius)
                if let insight = vm.latestInsight {
                    ObservatoryInsightCard(insight: insight, accent: accent, radius: radius)
                }
                observationCapture(vm, accent: accent, radius: radius)
                if !vm.observations.isEmpty {
                    ObservatoryObservationsList(observations: vm.observations, radius: radius)
                }
                reflectiveAsk(vm, accent: accent, radius: radius)
                if let answer = lastAnswer {
                    ObservatoryAnswerCard(answer: answer, accent: accent, radius: radius)
                }
                Spacer(minLength: 48)
            }
            .padding(20)
        }
    }

    private func awakenCard(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mercury is listening.")
                .font(.headline)
                .foregroundStyle(PersonaTheme.mercurySilver)
            Text("Enter the observational field: patterns, continuity, diagnostics, memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                Task { await vm.awakenEternal() }
            } label: {
                Text("Enter Observatory")
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
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func constellationPanel(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CONSTELLATION")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PersonaTheme.glowPurple)
                Spacer()
                Button {
                    isScanning = true
                    lastAnswer = nil
                    Task {
                        let result = await vm.runContinuityInstrument()
                        lastAnswer = result
                        isScanning = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        if isScanning { ProgressView().scaleEffect(0.7) }
                        Text(isScanning ? "Scanning…" : "Continuity")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }

            if vm.constellation.isEmpty {
                Text("No high-importance memory nodes yet. Capture observations to seed the field.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial.opacity(0.22), in: RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous))
            } else {
                ForEach(vm.constellation) { node in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(accent.opacity(0.35 + node.importance * 0.5))
                            .frame(width: 8, height: 8)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.summary)
                                .font(.caption)
                                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.92))
                            Text(node.category.uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial.opacity(0.25), in: RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous))
                }
            }
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
                    .background(
                        .ultraThinMaterial.opacity(0.38),
                        in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                    )
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

    private func reflectiveAsk(_ vm: EternalViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ASK THE OBSERVATORY")
                .font(.caption2.weight(.bold))
                .foregroundStyle(PersonaTheme.toxicGreen)
            TextField("Pattern, history, continuity, diagnose…", text: $askDraft, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    .ultraThinMaterial.opacity(0.38),
                    in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                )
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
                        ProgressView()
                            .tint(PersonaTheme.voidBlack)
                            .scaleEffect(0.8)
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
}
