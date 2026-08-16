import SwiftUI
import Core
import Nexus

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
        let personaID = container.activeConfiguration.id

        List {
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
        .onAppear {
            vm.refresh()
            vm.startLiveRefresh()
        }
    }
}
