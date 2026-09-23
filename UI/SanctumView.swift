import SwiftUI
import Core
import Personas
import Nexus

/// The Sanctum — primary experiential surface of Mercury.
/// Not a dashboard. A place.
/// Quicksilver is already here. Forge and Eternal are aspects of the same presence,
/// not separate products the user switches between.
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
            RealmGateway(title: "The Workshop", personaID: "forge", isPresented: $showForge) {
                ForgeView()
            }
        }
        .sheet(isPresented: $showEternal) {
            RealmGateway(title: "The Observatory", personaID: "eternal", isPresented: $showEternal) {
                EternalView()
            }
        }
    }

    private func sanctumContent(_ vm: SanctumViewModel) -> some View {
        // Drive visual language from the aspect the Brain selected, not a user picker.
        let accentID = vm.presenceAccentID
        let accent = PersonaTheme.accent(for: accentID)
        let radius = PersonaTheme.cardCornerRadius(for: accentID)

        return ZStack {
            // The Sanctum is an atmosphere first; instruments sit inside the field.
            MercurySanctumBackdrop(accent: accent)
                .ignoresSafeArea()

            AmbientLayer(
                personaID: accentID,
                visualState: vm.visualState
            )

            VStack(spacing: 0) {
                presenceBar(vm, accent: accent)
                sanctumScrollView(vm, accentID: accentID, accent: accent, radius: radius)
                ritualBar(accent: accent)
            }
        }
        .onAppear { vm.startLiveRefresh() }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(MotionTokens.spring(for: accentID), value: accentID)
        .animation(MotionTokens.spring(for: accentID), value: vm.livingStatus)
        .animation(MotionTokens.stabilization, value: vm.visualState)
        .animation(MotionTokens.spring(for: accentID), value: vm.activeAspect)
    }
}

private extension SanctumView {
    private func sanctumScrollView(
        _ vm: SanctumViewModel,
        accentID: String,
        accent: Color,
        radius: CGFloat
    ) -> some View {
        ScrollView {
            VStack(spacing: 28 * PersonaTheme.density(for: accentID)) {
                QuicksilverPresenceView(
                    personaID: accentID,
                    livingStatus: vm.livingStatus,
                    visualState: vm.visualState
                )

                GlyphStrip(
                    glyphs: glyphStates(for: vm),
                    personaID: accentID
                ) { kind in
                    handleGlyph(kind)
                }
                .padding(.vertical, 4)

                // Quiet passage markers — these open places in Mercury rather than
                // switching between assistants or products.
                chamberIndicators(vm, accent: accent, radius: radius)

                environmentalSignals(vm)

                if let insight = vm.latestInsight {
                    insightCard(insight, accent: accent, radius: radius)
                }

                Spacer(minLength: 64)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Glyph mapping

    private func glyphStates(for vm: SanctumViewModel) -> [(GlyphKind, GlyphVisualState)] {
        let healthState: GlyphVisualState = vm.overallHealthScore < 40 ? .warning : .idle
        let aspect = vm.activeAspect
        return [
            (.communication, .attention),
            (.memory, .idle),
            (.diagnostics, healthState),
            (.development, aspect == .forge ? .active : .idle),
            (.observation, aspect == .eternal ? .active : .idle),
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

    private func presenceBar(_ vm: SanctumViewModel, accent: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .shadow(color: accent.opacity(0.8), radius: 4)

            Text("SANCTUM")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(PersonaTheme.mercurySilver)

            Text("·")
                .foregroundStyle(.tertiary)

            Text(vm.visualState.rawValue.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.55))

            Spacer()

            Text(vm.livingStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.28))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(accent.opacity(0.18))
                .frame(height: 1)
        }
    }

    /// Realm passages remain spatial and restrained: each is a place to enter,
    /// not a tab or persona selector.
    private func chamberIndicators(_ vm: SanctumViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 10) {
            Button { showForge = true } label: {
                MercuryRealmPill(
                    title: "Workshop",
                    subtitle: vm.activeAspect == .forge ? "Present · Forge" : "Enter · Forge",
                    accent: PersonaTheme.accent(for: "forge"),
                    active: vm.activeAspect == .forge
                )
            }
            .buttonStyle(.plain)

            Button { showEternal = true } label: {
                MercuryRealmPill(
                    title: "Observatory",
                    subtitle: vm.activeAspect == .eternal ? "Present · Eternal" : "Enter · Eternal",
                    accent: PersonaTheme.accent(for: "eternal"),
                    active: vm.activeAspect == .eternal
                )
            }
            .buttonStyle(.plain)
        }
        .animation(MotionTokens.realmTransition, value: vm.activeAspect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mercury realms")
    }

    private func environmentalSignals(_ vm: SanctumViewModel) -> some View {
        HStack(spacing: 16) {
            signalPill(title: "Battery", value: vm.batteryLevelText)
            signalPill(title: "Network", value: vm.networkStatus)
            signalPill(title: "Thermal", value: vm.thermalState)
            signalPill(title: "Health", value: "\(vm.overallHealthScore)")
        }
        .padding(.horizontal, 4)
        .opacity(0.78)
    }

    private func signalPill(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
                .fill(.ultraThinMaterial.opacity(0.34))
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
            .background(.ultraThinMaterial.opacity(0.42))
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
