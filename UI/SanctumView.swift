import SwiftUI
import Core
import Personas
import Nexus

/// The Sanctum — primary experiential surface of Mercury.
/// Not a dashboard. A place.
/// Quicksilver is already here. Forge and Eternal awaken via persona.
struct SanctumView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SanctumViewModel?
    @State private var showAsk = false
    @State private var showCodex = false
    @State private var showMemory = false
    @State private var showForge = false
    @State private var showEternal = false
    @State private var showDiagnostics = false

    var body: some View {
        Group {
            if let viewModel {
                sanctumContent(viewModel)
            } else {
                PersonaTheme.voidBlack.ignoresSafeArea()
                    .onAppear { viewModel = SanctumViewModel(container: container) }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAsk) {
            NavigationStack { AskView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showCodex) {
            NavigationStack { CodexView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showMemory) {
            NavigationStack { MemoryView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack { DiagnosticsView() }
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showForge) {
            RealmGateway(title: "Forge", personaID: "forge", isPresented: $showForge) {
                ForgeView()
            }
        }
        .sheet(isPresented: $showEternal) {
            RealmGateway(title: "Eternal", personaID: "eternal", isPresented: $showEternal) {
                EternalView()
            }
        }
    }

    private func sanctumContent(_ vm: SanctumViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)

        return ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()

            AmbientLayer(
                personaID: personaID,
                visualState: vm.visualState
            )

            VStack(spacing: 0) {
                presenceBar(vm, accent: accent, radius: radius)

                ScrollView {
                    VStack(spacing: 28 * PersonaTheme.density(for: personaID)) {
                        QuicksilverPresenceView(
                            personaID: personaID,
                            livingStatus: vm.livingStatus,
                            visualState: vm.visualState
                        )

                        GlyphStrip(
                            glyphs: glyphStates(for: vm),
                            personaID: personaID
                        ) { kind in
                            handleGlyph(kind)
                        }
                        .padding(.vertical, 4)

                        personaIndicators(vm, accent: accent, radius: radius)

                        environmentalSignals(vm, radius: radius)

                        if let insight = vm.latestInsight {
                            insightCard(insight, accent: accent, radius: radius)
                        }

                        Spacer(minLength: 64)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                ritualBar(accent: accent)
            }
        }
        .onAppear { vm.startLiveRefresh() }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(MotionTokens.spring(for: personaID), value: personaID)
        .animation(MotionTokens.spring(for: personaID), value: vm.livingStatus)
        .animation(MotionTokens.stabilization, value: vm.visualState)
    }

}

private extension SanctumView {
    // MARK: - Glyph mapping

    private func glyphStates(for vm: SanctumViewModel) -> [(GlyphKind, GlyphVisualState)] {
        let healthState: GlyphVisualState = vm.overallHealthScore < 40 ? .warning : .idle
        let persona = vm.activePersonaID.lowercased()
        return [
            (.communication, .attention),
            (.memory, .idle),
            (.diagnostics, healthState),
            (.development, persona == "forge" ? .active : .idle),
            (.observation, persona == "eternal" ? .active : .idle),
            (.configuration, .idle),
            (.health, healthState),
            (.network, .idle)
        ]
    }

    private func handleGlyph(_ kind: GlyphKind) {
        switch kind {
        case .communication: showAsk = true
        case .memory: showMemory = true
        case .diagnostics, .health: showDiagnostics = true
        case .development, .creation: showForge = true
        case .observation: showEternal = true
        case .configuration: showCodex = true
        case .network, .security, .intelligence:
            showDiagnostics = true
        }
    }

    private func presenceBar(_ vm: SanctumViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .shadow(color: accent.opacity(0.8), radius: 4)

            Text(vm.activePersonaID.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PersonaTheme.mercurySilver)

            Spacer()

            Text(vm.visualState.rawValue.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.5))
                .padding(.trailing, 6)

            Text(vm.livingStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.35))
    }

    private func personaIndicators(_ vm: SanctumViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button { showForge = true } label: {
                personaChip(
                    name: "Forge",
                    isAwake: vm.activePersonaID.lowercased() == "forge" || vm.activePersonaID.lowercased() == "quicksilver",
                    accent: PersonaTheme.accent(for: "forge"),
                    radius: radius
                )
            }
            .buttonStyle(.plain)

            Button { showEternal = true } label: {
                personaChip(
                    name: "Eternal",
                    isAwake: vm.activePersonaID.lowercased() == "eternal" || vm.activePersonaID.lowercased() == "quicksilver",
                    accent: PersonaTheme.accent(for: "eternal"),
                    radius: radius
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func personaChip(name: String, isAwake: Bool, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isAwake ? accent : accent.opacity(0.25))
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption2.weight(isAwake ? .semibold : .regular))
                .foregroundStyle(isAwake ? PersonaTheme.mercurySilver : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                .fill(.ultraThinMaterial.opacity(isAwake ? 0.55 : 0.25))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                .strokeBorder(accent.opacity(isAwake ? 0.45 : 0.12), lineWidth: 1)
        )
    }

    private func environmentalSignals(_ vm: SanctumViewModel, radius: CGFloat) -> some View {
        HStack(spacing: 10) {
            signalPill(title: "Battery", value: vm.batteryLevelText)
            signalPill(title: "Network", value: vm.networkStatus)
            signalPill(title: "Thermal", value: vm.thermalState)
            signalPill(title: "Health", value: "\(vm.overallHealthScore)")
        }
    }

    private func signalPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))
        )
    }

    private func insightCard(_ insight: Insight, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insight")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
            Text(insight.title)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func ritualBar(accent: Color) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(accent.opacity(0.2))
                .frame(height: 1)

            HStack {
                ritualButton(systemImage: "bubble.left.and.bubble.right", label: "Invoke") {
                    showAsk = true
                }
                Spacer()
                ritualButton(systemImage: "brain.head.profile", label: "Memory") {
                    showMemory = true
                }
                Spacer()
                ritualButton(systemImage: "scroll", label: "Codex") {
                    showCodex = true
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial.opacity(0.5))
        }
    }

    private func ritualButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9))
        }
        .buttonStyle(.plain)
    }
}
