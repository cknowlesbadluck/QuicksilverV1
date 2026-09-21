import SwiftUI
import Core
import Nexus

struct DiagnosticsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: DiagnosticsViewModel?

    var body: some View {
        let personaID = container.activeConfiguration.id
        let accent = PersonaTheme.accent(for: personaID)

        ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()

            Group {
                if let vm = viewModel {
                    content(vm, personaID: personaID, accent: accent)
                } else {
                    ProgressView()
                        .tint(accent)
                        .onAppear { viewModel = DiagnosticsViewModel(container: container) }
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(PersonaTheme.voidBlack, for: .navigationBar)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { viewModel?.refresh() }
                    .foregroundStyle(accent)
            }
        }
        .onDisappear { viewModel?.stopLiveRefresh() }
    }

    @ViewBuilder
    private func content(_ vm: DiagnosticsViewModel, personaID: String, accent: Color) -> some View {
        List {
            statusSection(vm, personaID: personaID, accent: accent)
            insightsSection(vm, personaID: personaID, accent: accent)
            signalsSection(vm, personaID: personaID, accent: accent)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
    }

    @ViewBuilder
    private func statusSection(_ vm: DiagnosticsViewModel, personaID: String, accent: Color) -> some View {
        Section {
            diagRow("Nexus", value: vm.isActive ? "Active" : "Inactive", accent: vm.isActive ? PersonaTheme.toxicGreen : .secondary)
            diagRow("Health", value: "\(vm.overallHealth)", accent: PersonaTheme.healthColor(vm.overallHealth))
            diagRow("Network", value: vm.networkStatus, accent: PersonaTheme.mercurySilver)
            diagRow("Battery", value: vm.batteryText, accent: PersonaTheme.mercurySilver)
            diagRow("Thermal", value: vm.thermal, accent: PersonaTheme.mercurySilver)
            if vm.lowPower {
                diagRow("Power", value: "Low Power Mode", accent: PersonaTheme.hazardGreen)
            }
            diagRow("Last refresh", value: vm.lastRefresh.formatted(date: .omitted, time: .standard), accent: .secondary)
        } header: {
            Text("SYSTEM STATUS")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(accent)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func insightsSection(_ vm: DiagnosticsViewModel, personaID: String, accent: Color) -> some View {
        Section {
            if vm.insights.isEmpty {
                Text("No insights recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.insights) { insight in
                    let display = InsightPresenter.present(insight, personaID: personaID)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PersonaTheme.mercuryBright)
                        Text(display.body)
                            .font(.caption)
                            .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.8))
                        HStack {
                            Text(display.styleLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(accent)
                            if let action = display.action {
                                Text("· \(action)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text("INSIGHTS STREAM")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(accent)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    @ViewBuilder
    private func signalsSection(_ vm: DiagnosticsViewModel, personaID: String, accent: Color) -> some View {
        Section {
            if vm.recentSignals.isEmpty {
                Text("No signals captured")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.recentSignals) { signal in
                    HStack {
                        Text(signal.source.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(accent.opacity(0.85))
                            .frame(width: 76, alignment: .leading)
                        Text(signal.value)
                            .font(.subheadline)
                            .foregroundStyle(PersonaTheme.mercuryBright)
                        Spacer()
                        Text(signal.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: {
            Text("LIVE SIGNALS")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(accent)
        }
        .listRowBackground(Color.white.opacity(0.04))
    }

    private func diagRow(_ title: String, value: String, accent: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.8))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(accent)
        }
    }
}
