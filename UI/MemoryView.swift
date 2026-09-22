import SwiftUI
import UIKit
import Core
import Memory

struct MemoryView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: MemoryViewModel?
    @State private var draft = ""
    @State private var showClearConfirm = false
    @State private var sharePayload: SharePayload?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = MemoryViewModel(container: container) }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel?.prepareExport()
                    if let json = viewModel?.lastExportJSON {
                        sharePayload = SharePayload(text: json)
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(viewModel?.items.isEmpty ?? true)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(viewModel?.items.isEmpty ?? true)
            }
        }
        .confirmationDialog("Clear all memories? This cannot be undone.", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                Task { await viewModel?.clearAll() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: [payload.text])
        }
    }

    @ViewBuilder
    private func content(_ vm: MemoryViewModel) -> some View {
        let accent = PersonaTheme.accent(for: container.activeConfiguration.id)

        List {
            Section {
                HStack {
                    TextField("Quick note…", text: $draft)
                    Button("Save") {
                        Task {
                            await vm.addQuickNote(draft)
                            draft = ""
                        }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(accent)
                }
            } header: {
                if !vm.activePolicyLabel.isEmpty {
                    Text("Policy: \(vm.activePolicyLabel)")
                        .foregroundStyle(accent)
                }
            }

            Section("Stored (by importance)") {
                if vm.isLoading {
                    ProgressView()
                } else if vm.items.isEmpty {
                    Text("No memories match current policy")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.items) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.key)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                importanceBadge(item.importance)
                            }
                            Text(item.value).font(.body)
                            HStack {
                                Text(item.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                if let scope = item.personaScope {
                                    Text("· \(scope)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.delete(id: item.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .task { await vm.load() }
    }

    private func importanceBadge(_ value: Double) -> some View {
        let percent = Int(value * 100)
        let color: Color = value >= 0.7 ? .green : (value >= 0.4 ? .orange : .secondary)
        return Text("\(percent)%")
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let text: String
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
