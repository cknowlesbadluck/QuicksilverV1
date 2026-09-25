import SwiftUI
import Core

/// The Codex — governance of Mercury himself.
/// Not a settings screen. The user is altering the fundamental laws.
struct CodexView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SettingsViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let vm = viewModel {
                codexContent(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = SettingsViewModel(container: container) }
            }
        }
        .navigationTitle("The Codex")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Seal") { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func codexContent(_ vm: SettingsViewModel) -> some View {
        Form {
            Section {
                Toggle("Intelligence Active", isOn: Binding(
                    get: { vm.aiEnabled },
                    set: { vm.setAIEnabled($0) }
                ))
                LabeledContent("Vessel", value: vm.providerName)
                LabeledContent("Key bound", value: (vm.hasGrokKey || vm.hasGeminiKey) ? "Yes — Keychain" : "Unbound")
            } header: {
                Text("Mind")
            } footer: {
                Text("Credentials remain sealed in the device Keychain. They never leave the device in logs or defaults.")
            }

            Section {
                SecureField("Gemini / Google API key", text: Binding(
                    get: { vm.geminiKeyDraft },
                    set: { vm.geminiKeyDraft = $0 }
                ))
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button("Bind Gemini") {
                    vm.saveGeminiKey()
                    if vm.hasGeminiKey { vm.setAIEnabled(true) }
                }
                .disabled(vm.geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                LabeledContent("Gemini", value: vm.hasGeminiKey ? "Bound — Keychain" : "Unbound")
                if vm.hasGeminiKey {
                    Button("Unbind Gemini", role: .destructive) {
                        vm.clearGeminiKey()
                    }
                }

                SecureField("Grok / xAI API key (optional)", text: Binding(
                    get: { vm.grokKeyDraft },
                    set: { vm.grokKeyDraft = $0 }
                ))
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button("Bind Grok") {
                    vm.saveGrokKey()
                    if vm.hasGrokKey { vm.setAIEnabled(true) }
                }
                .disabled(vm.grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                LabeledContent("Grok", value: vm.hasGrokKey ? "Bound — Keychain" : "Unbound")
                if vm.hasGrokKey {
                    Button("Unbind Grok", role: .destructive) {
                        vm.clearGrokKey()
                    }
                }

                LabeledContent("Routing", value: vm.fallbackProviderName.map { "\(vm.providerName) / \($0)" } ?? vm.providerName)

                Button("Remove all provider keys", role: .destructive) {
                    container.aiService.clearAllAPIKeys()
                    vm.refresh()
                }
            } header: {
                Text("Covenant")
            } footer: {
                Text("Gemini free-tier key is the interim cloud bind. Grok is optional. The Mercury Gateway will replace these fields (M3-T6 / M3-T22).")
            }

            if let message = vm.statusMessage {
                Section {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(vm.statusIsError ? .red : .secondary)
                }
            }

            Section {
                LabeledContent("Version", value: container.configuration.fullVersionString)
                LabeledContent("Sanctum", value: "Phase II")
            } header: {
                Text("Record")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PersonaTheme.cosmicBlack)
        .onAppear { vm.refresh() }
    }
}
