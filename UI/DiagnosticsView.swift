import SwiftUI
import Core
import Nexus

/// Diagnostics show the Brain's current state without changing its aspect.
struct DiagnosticsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: DiagnosticsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = DiagnosticsViewModel(container: container) }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") { viewModel?.refresh() }
            }
        }
        .onDisappear { viewModel?.stopLiveRefresh() }
    }

    @ViewBuilder
    private func content(_ vm: DiagnosticsViewModel) -> some View {
        let personaID = container.brain.activeAspect.rawValue

        List {
            aspectStateSection
            ownerGateSection
            statusSection(vm)
            insightsSection(vm, personaID: personaID)
            signalsSection(vm)
        }
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
    }

    @ViewBuilder
    private var aspectStateSection: some View {
        Section {
            HStack {
                Text("Active")
                Spacer()
                Text(container.brain.activeAspect.diagnosticLabel)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Visual")
                Spacer()
                Text(container.brain.visualState.rawValue)
                    .foregroundStyle(.secondary)
            }

        } header: {
            Text("Quicksilver state")
        } footer: {
            Text("Quicksilver chooses the aspect that fits the current context.")
        }
    }

    /// Owner gates stay unproven until evidence exists. This view does not fetch secrets or claim a device archive.
    @ViewBuilder
    private var ownerGateSection: some View {
        Section {
            ForEach(OwnerGateBoard.current()) { gate in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(gate.title)
                        Spacer()
                        Text(gate.statusLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PersonaTheme.readableSecondary)
                    }
                    Text(gate.ownerAction)
                        .font(.caption)
                        .foregroundStyle(PersonaTheme.readableSecondary)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Owner gates")
        } footer: {
            Text(OwnerGateBoard.latestProbe.footer(asOf: Date()))
                .accessibilityLabel(OwnerGateBoard.latestProbe.footer(asOf: Date()))
        }
    }

    @ViewBuilder
    private func statusSection(_ vm: DiagnosticsViewModel) -> some View {
        Section("Status") {
            LabeledContent("Nexus", value: vm.isActive ? "Active" : "Inactive")
            LabeledContent("Health", value: "\(vm.overallHealth)")
            LabeledContent("Network", value: vm.networkStatus)
            LabeledContent("Battery", value: vm.batteryText)
            LabeledContent("Thermal", value: vm.thermal)
            if vm.lowPower {
                LabeledContent("Power", value: "Low Power Mode")
            }
            LabeledContent("Last refresh", value: vm.lastRefresh.formatted(date: .omitted, time: .standard))
        }
    }

    @ViewBuilder
    private func insightsSection(_ vm: DiagnosticsViewModel, personaID: String) -> some View {
        Section("Insights") {
            if vm.insights.isEmpty {
                Text("No insights yet").foregroundStyle(.secondary)
            } else {
                ForEach(vm.insights) { insight in
                    let display = InsightPresenter.present(insight, personaID: personaID)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(display.title).font(.subheadline.weight(.medium))
                        Text(display.body).font(.caption).foregroundStyle(.secondary)
                        Text(display.styleLabel).font(.caption2).foregroundStyle(.tertiary)
                        if let action = display.action {
                            Text(action).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func signalsSection(_ vm: DiagnosticsViewModel) -> some View {
        Section("Recent Signals") {
            if vm.recentSignals.isEmpty {
                Text("No signals yet").foregroundStyle(.secondary)
            } else {
                ForEach(vm.recentSignals) { signal in
                    HStack {
                        Text(signal.source.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 72, alignment: .leading)
                        Text(signal.value).font(.subheadline)
                        Spacer()
                        Text(signal.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
