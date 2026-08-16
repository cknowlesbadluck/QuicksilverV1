import SwiftUI
import Core

struct SettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = SettingsViewModel(container: container) }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ vm: SettingsViewModel) -> some View {
        Form {
            intelligenceSection(vm)
            personasSection(vm)
            apiKeySection(vm)
            statusSection(vm)
        }
        .onAppear { vm.refresh() }
    }

    @ViewBuilder
    private func intelligenceSection(_ vm: SettingsViewModel) -> some View {
        Section {
            Toggle("AI Service", isOn: Binding(
                get: { vm.aiEnabled },
                set: { vm.setAIEnabled($0) }
            ))
            LabeledContent("Provider", value: vm.providerName)
            LabeledContent("Key stored", value: vm.hasStoredKey ? "Yes (Keychain)" : "No")
        } header: {
            Text("Intelligence")
        } footer: {
            Text(
                "Keys are stored in the device Keychain (AfterFirstUnlockThisDeviceOnly). "
                + "They are never written to UserDefaults or logs."
            )
        }
    }

    @ViewBuilder
    private func personasSection(_ vm: SettingsViewModel) -> some View {
        Section {
            Toggle("Persona Autonomy", isOn: Binding(
                get: { vm.personaAutonomyEnabled },
                set: { vm.setPersonaAutonomy($0) }
            ))
            if let reason = vm.lastSwitchReason {
                LabeledContent("Last switch", value: reason)
            }
        } header: {
            Text("Personas")
        } footer: {
            Text(
                "When enabled, Quicksilver may switch personas based on task, battery, thermal, "
                + "and time context. Manual switches always work."
            )
        }
    }

    @ViewBuilder
    private func apiKeySection(_ vm: SettingsViewModel) -> some View {
        Section("xAI API Key") {
            SecureField("Paste xAI API key", text: Binding(
                get: { vm.apiKeyDraft },
                set: { vm.apiKeyDraft = $0 }
            ))
            .textContentType(.password)
            .autocorrectionDisabled()

            Button("Save Key") {
                vm.saveAPIKey()
            }
            .disabled(vm.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if vm.hasStoredKey {
                Button("Remove Key", role: .destructive) {
                    vm.clearAPIKey()
                }
            }
        }
    }

    @ViewBuilder
    private func statusSection(_ vm: SettingsViewModel) -> some View {
        if let message = vm.statusMessage {
            Section {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(vm.statusIsError ? .red : .secondary)
            }
        }
    }
}
