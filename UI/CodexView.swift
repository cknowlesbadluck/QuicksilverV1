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
                LabeledContent("Key bound", value: vm.hasStoredKey ? "Yes — Keychain" : "Unbound")
            } header: {
                Text("Mind")
            } footer: {
                Text("Credentials remain sealed in the device Keychain. They never leave the device in logs or defaults.")
            }

            Section {
                Toggle("Autonomous Persona Shifts", isOn: Binding(
                    get: { vm.personaAutonomyEnabled },
                    set: { vm.setPersonaAutonomy($0) }
                ))
                if let reason = vm.lastSwitchReason {
                    LabeledContent("Last shift", value: reason)
                }
            } header: {
                Text("Identity")
            } footer: {
                Text("When enabled, Mercury may shift between Quicksilver, Forge, and Eternal according to task, pressure, and time. Manual shifts always take precedence.")
            }

            Section {
                SecureField("Bind xAI key", text: Binding(
                    get: { vm.apiKeyDraft },
                    set: { vm.apiKeyDraft = $0 }
                ))
                .textContentType(.password)
                .autocorrectionDisabled()

                Button("Bind Key") {
                    vm.saveAPIKey()
                }
                .disabled(vm.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if vm.hasStoredKey {
                    Button("Unbind Key", role: .destructive) {
                        vm.clearAPIKey()
                    }
                }
            } header: {
                Text("Covenant")
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
