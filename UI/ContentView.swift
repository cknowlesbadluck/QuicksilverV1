import SwiftUI
import UIKit
import Core
import Personas
import Nexus

struct ContentView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: HomeViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm = viewModel {
                    dashboard(vm)
                } else {
                    ProgressView()
                        .onAppear { viewModel = HomeViewModel(container: container) }
                }
            }
            .navigationTitle("Mercury")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink { AskView() } label: {
                        Label("Ask", systemImage: "text.bubble")
                    }
                    NavigationLink { DiagnosticsView() } label: {
                        Label("Diagnostics", systemImage: "waveform.path.ecg")
                    }
                    NavigationLink { MemoryView() } label: {
                        Label("Memory", systemImage: "brain.head.profile")
                    }
                    NavigationLink { SettingsView() } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .background(PersonaTheme.voidBlack.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func dashboard(_ vm: HomeViewModel) -> some View {
        let personaID = vm.activePersonaID
        let accent = PersonaTheme.accent(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)
        let spacing = 20 * PersonaTheme.density(for: personaID)

        ScrollView {
            VStack(spacing: spacing) {
                // Living status — insight-first, not raw metrics
                livingStatusCard(vm, accent: accent, radius: radius)

                personaHeader(vm, accent: accent, radius: radius)
                personaSwitcher(vm)
                nexusStatusCard(vm, radius: radius)
                metricsRow(vm, radius: radius)

                if let insight = vm.latestInsight {
                    insightCard(insight, personaID: personaID, accent: accent, radius: radius)
                }
            }
            .padding()
        }
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
        .onDisappear {
            vm.stopLiveRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.refresh()
        }
        .animation(PersonaTheme.spring(for: personaID), value: personaID)
    }

    private func livingStatusCard(_ vm: HomeViewModel, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 8, height: 8)
                .opacity(0.9)

            Text(vm.livingStatus)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver)
                .lineLimit(2)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }

    private func personaHeader(_ vm: HomeViewModel, accent: Color, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.personaDisplayName)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(PersonaTheme.mercurySilver)
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 12, height: 12)
                    .shadow(color: accent.opacity(0.6), radius: 6)
            }
            Text(vm.personaDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let reason = vm.lastSwitchReason {
                Text("Switched: \(reason)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func personaSwitcher(_ vm: HomeViewModel) -> some View {
        Picker("Persona", selection: Binding(
            get: { vm.activePersonaID },
            set: { vm.switchPersona(to: $0) }
        )) {
            ForEach(vm.availablePersonas, id: \.id) { config in
                Text(config.displayName).tag(config.id)
            }
        }
        .pickerStyle(.segmented)
    }

    private func nexusStatusCard(_ vm: HomeViewModel, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Nexus", systemImage: "antenna.radiowaves.left.and.right").font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(vm.isNexusActive ? PersonaTheme.toxicGreen : .secondary).frame(width: 8, height: 8)
                    Text(vm.isNexusActive ? "Active" : "Inactive").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Overall health").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.overallHealthScore)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PersonaTheme.healthColor(vm.overallHealthScore))
            }
            if vm.lowPowerMode {
                Label("Low Power Mode", systemImage: "battery.25").font(.caption).foregroundStyle(PersonaTheme.hazardGreen)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private func metricsRow(_ vm: HomeViewModel, radius: CGFloat) -> some View {
        HStack(spacing: 12) {
            metricTile(title: "Battery", value: vm.batteryLevelText, subtitle: vm.batteryState, systemImage: "battery.100", radius: radius)
            metricTile(title: "Network", value: vm.networkStatus, subtitle: vm.networkSubtitle, systemImage: "wifi", radius: radius)
            metricTile(title: "Thermal", value: vm.thermalState, subtitle: nil, systemImage: "thermometer.medium", radius: radius)
        }
    }

    private func metricTile(title: String, value: String, subtitle: String?, systemImage: String, radius: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.semibold)).lineLimit(1)
            if let subtitle {
                Text(subtitle).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: max(8, radius - 4), style: .continuous))
    }

    private func insightCard(_ insight: Insight, personaID: String, accent: Color, radius: CGFloat) -> some View {
        let display = InsightPresenter.present(insight, personaID: personaID)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Latest Insight", systemImage: "sparkles").font(.headline)
                Spacer()
                Text(display.styleLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(accent)
            }
            Text(display.title).font(.subheadline.weight(.medium))
            Text(display.body).font(.caption).foregroundStyle(.secondary)
            if let action = display.action {
                Text(action).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}
