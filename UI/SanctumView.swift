import SwiftUI
import Core
import Personas
import Nexus

/// The Sanctum — primary experiential surface of Mercury.
/// Not a dashboard. A place.
/// Quicksilver is already here. The Forge and Eternal awaken organically.
struct SanctumView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SanctumViewModel?
    @State private var showAsk = false
    @State private var showCodex = false
    @State private var showMemory = false
    @State private var showForge = false
    @State private var showEternal = false

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
            NavigationStack {
                AskView()
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showCodex) {
            NavigationStack {
                CodexView()
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showMemory) {
            NavigationStack {
                MemoryView()
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showForge) {
            NavigationStack {
                ForgeView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showForge = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showEternal) {
            NavigationStack {
                EternalView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showEternal = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func sanctumContent(_ vm: SanctumViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)

        return ZStack {
            // Radioactive void — the chamber is larger than the screen
            PersonaTheme.voidBlack.ignoresSafeArea()

            AmbientLayer(personaID: personaID, chamber: vm.activeChamber)

            // Main Sanctum content
            VStack(spacing: 0) {
                presenceBar(vm, accent: accent, radius: radius)

                ScrollView {
                    VStack(spacing: 24 * PersonaTheme.density(for: personaID)) {
                        // Living core — no card chrome
                        QuicksilverPresenceView(
                            personaID: personaID,
                            chamber: vm.activeChamber,
                            livingStatus: vm.livingStatus,
                            visualState: vm.visualState
                        )

                        // Realm gateways
                        chamberIndicators(vm, accent: accent, radius: radius)

                        // Environmental signals (Nexus) — progressive disclosure
                        environmentalSignals(vm, radius: radius)

                        if let insight = vm.latestInsight {
                            insightCard(insight, accent: accent, radius: radius)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                // Ritual bar — invocation instruments
                ritualBar(accent: accent)
            }
        }
        .onAppear { vm.startLiveRefresh() }
        .onDisappear { vm.stopLiveRefresh() }
        .animation(MotionTokens.spring(for: personaID), value: vm.activeChamber)
        .animation(MotionTokens.spring(for: personaID), value: vm.livingStatus)
        .animation(MotionTokens.stabilization, value: vm.visualState)
    }

    // MARK: - Presence Bar

    private func presenceBar(_ vm: SanctumViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .shadow(color: accent.opacity(0.8), radius: 4)

            Text(vm.activeChamber.displayName)
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

    // MARK: - Chamber Indicators (Realm Gateways)

    private func chamberIndicators(_ vm: SanctumViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button {
                showForge = true
            } label: {
                chamberChip(
                    name: "Forge",
                    isAwake: vm.activeChamber == .forge || vm.activeChamber == .sanctum,
                    accent: PersonaTheme.accent(for: "forge"),
                    radius: radius
                )
            }
            .buttonStyle(.plain)

            Button {
                showEternal = true
            } label: {
                chamberChip(
                    name: "Eternal",
                    isAwake: vm.activeChamber == .eternal || vm.activeChamber == .sanctum,
                    accent: PersonaTheme.accent(for: "eternal"),
                    radius: radius
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func chamberChip(name: String, isAwake: Bool, accent: Color, radius: CGFloat) -> some View {
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

    // MARK: - Environmental Signals

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

    // MARK: - Insight

    private func insightCard(_ insight: Insight, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insight")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(accent)
            Text(insight.summary)
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

    // MARK: - Ritual Bar

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
