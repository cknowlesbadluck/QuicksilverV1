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
                        .onAppear { viewModel = MemoryViewModel(container: container) }
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(PersonaTheme.voidBlack, for: .navigationBar)
        .preferredColorScheme(.dark)
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
    private func content(_ vm: MemoryViewModel, personaID: String, accent: Color) -> some View {
        let radius = PersonaTheme.cardCornerRadius(for: personaID)

        List {
            Section {
                HStack(spacing: 10) {
                    TextField("Quick note…", text: $draft)
                        .font(.subheadline)
                        .foregroundStyle(PersonaTheme.mercurySilver)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                        )

                    Button("Save") {
                        Task {
                            await vm.addQuickNote(draft)
                            draft = ""
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(accent.opacity(0.22), in: RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .foregroundStyle(accent)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            } header: {
                if !vm.activePolicyLabel.isEmpty {
                    Text("POLICY: \(vm.activePolicyLabel.uppercased())")
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(accent)
                }
            }

            Section {
                if vm.isLoading {
                    HStack {
                        Spacer()
                        ProgressView().tint(accent)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if vm.items.isEmpty {
                    Text("No memories match current policy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(vm.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.key)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.6)
                                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.75))
                                Spacer()
                                importanceBadge(item.importance)
                            }
                            Text(item.value)
                                .font(.subheadline)
                                .foregroundStyle(PersonaTheme.mercuryBright)
                            HStack {
                                Text(item.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                if let scope = item.personaScope {
                                    Text("· \(scope.capitalized)")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(accent.opacity(0.8))
                                }
                            }
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .fill(.ultraThinMaterial.opacity(0.42))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: radius, style: .continuous)
                                .strokeBorder(PersonaTheme.borderColor(for: personaID).opacity(0.3), lineWidth: 1)
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.delete(id: item.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("STORED MEMORIES")
                    .font(.caption2.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .task { await vm.load() }
    }

    private func importanceBadge(_ value: Double) -> some View {
        let percent = Int(value * 100)
        let color: Color = value >= 0.7 ? PersonaTheme.toxicGreen : (value >= 0.4 ? PersonaTheme.hazardGreen : .secondary)
        return Text("\(percent)%")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.8))
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
