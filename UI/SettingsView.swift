// swiftlint:disable function_body_length
// swiftlint:disable function_body_length\nimport SwiftUI
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
            credentialsSection(vm)
            personasSection(vm)
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
            LabeledContent("Primary", value: vm.providerName)
            if let fallback = vm.fallbackProviderName {
                LabeledContent("Fallback", value: fallback)
            }
            LabeledContent("Grok", value: vm.hasGrokKey ? "Configured" : "Not configured")
            LabeledContent("Gemini", value: vm.hasGeminiKey ? "Configured" : "Not configured")
            LabeledContent("Routing", value: "Automatic")
            LabeledContent("Billing", value: "Free tier only")
        } header: {
            Text("Intelligence")
        } footer: {
            Text(
                "Grok is Quicksilver's conversational default. Gemini is the automatic fallback. "
                + "Keys remain on this device in the Keychain."
            )
        }
    }
    
    @ViewBuilder
    private func credentialsSection(_ vm: SettingsViewModel) -> some View {
        Section("API Keys") {
            grokCredentials(vm)
            Divider()
            geminiCredentials(vm)
        }
    }
    
    @ViewBuilder
    private func grokCredentials(_ vm: SettingsViewModel) -> some View {
        SecureField("Grok / xAI API key", text: Binding(
            get: { vm.grokKeyDraft },
            set: { vm.grokKeyDraft = $0 }
        ))
        .textContentType(.password)
        .autocorrectionDisabled()
        
        Button("Save Grok Key") {
            vm.saveGrokKey()
        }
        .disabled(vm.grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        if vm.hasGrokKey {
            Button("Remove Grok Key", role: .destructive) {
                vm.clearGrokKey()
            }
        }
    }
    
    @ViewBuilder
    private func geminiCredentials(_ vm: SettingsViewModel) -> some View {
        SecureField("Gemini / Google API key", text: Binding(
            get: { vm.geminiKeyDraft },
            set: { vm.geminiKeyDraft = $0 }
        ))
        .textContentType(.password)
        .autocorrectionDisabled()
        
        Button("Save Gemini Key") {
            vm.saveGeminiKey()
        }
        .disabled(vm.geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        if vm.hasGeminiKey {
            Button("Remove Gemini Key", role: .destructive) {
                vm.clearGeminiKey()
            }
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
            Text("Aspects")
        } footer: {
            Text(
                "Aspect surfacing remains automatic. The intelligence provider is independent "
                + "of Quicksilver, Forge, and Eternal."
            )
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
// swiftlint:enable function_body_length\n
// swiftlint:enable function_body_length
