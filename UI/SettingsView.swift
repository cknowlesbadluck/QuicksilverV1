import SwiftUI
import Core

struct SettingsView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SettingsViewModel?
    
    var body: some View {
        Form {
            if let vm = viewModel {
                IntelligenceSettingsSection(viewModel: vm)
                CredentialSettingsSection(viewModel: vm)
                AspectSettingsSection(viewModel: vm)
                StatusSettingsSection(viewModel: vm)
            }
        }
        .overlay {
            if viewModel == nil {
                ProgressView()
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil {
                viewModel = SettingsViewModel(container: container)
            }
        }
    }
}

private struct IntelligenceSettingsSection: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        Section {
            Toggle("AI Service", isOn: Binding(
                get: { viewModel.aiEnabled },
                set: { viewModel.setAIEnabled($0) }
            ))
            LabeledContent("Primary", value: viewModel.providerName)
            if let fallback = viewModel.fallbackProviderName {
                LabeledContent("Fallback", value: fallback)
            }
            LabeledContent(
                "Grok",
                value: viewModel.hasGrokKey ? "Configured" : "Not configured"
            )
            LabeledContent(
                "Gemini",
                value: viewModel.hasGeminiKey ? "Configured" : "Not configured"
            )
            LabeledContent("Routing", value: "Automatic")
            LabeledContent("Billing", value: "Account free tier")
        } header: {
            Text("Intelligence")
        } footer: {
            Text(
                "Grok is Quicksilver's conversational default. Gemini is the automatic fallback. "
                + "Keys remain on this device in the Keychain."
            )
        }
    }
}

private struct CredentialSettingsSection: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        Section("API Keys") {
            GrokCredentialFields(viewModel: viewModel)
            Divider()
            GeminiCredentialFields(viewModel: viewModel)
        }
    }
}

private struct GrokCredentialFields: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        SecureField("Grok / xAI API key", text: Binding(
            get: { viewModel.grokKeyDraft },
            set: { viewModel.grokKeyDraft = $0 }
        ))
        .textContentType(.password)
        .autocorrectionDisabled()
        
        Button("Save Grok Key") {
            viewModel.saveGrokKey()
        }
        .disabled(viewModel.grokKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        if viewModel.hasGrokKey {
            Button("Remove Grok Key", role: .destructive) {
                viewModel.clearGrokKey()
            }
        }
    }
}

private struct GeminiCredentialFields: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        SecureField("Gemini / Google API key", text: Binding(
            get: { viewModel.geminiKeyDraft },
            set: { viewModel.geminiKeyDraft = $0 }
        ))
        .textContentType(.password)
        .autocorrectionDisabled()
        
        Button("Save Gemini Key") {
            viewModel.saveGeminiKey()
        }
        .disabled(viewModel.geminiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        
        if viewModel.hasGeminiKey {
            Button("Remove Gemini Key", role: .destructive) {
                viewModel.clearGeminiKey()
            }
        }
    }
}

private struct AspectSettingsSection: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        Section {
            Toggle("Persona Autonomy", isOn: Binding(
                get: { viewModel.personaAutonomyEnabled },
                set: { viewModel.setPersonaAutonomy($0) }
            ))
            if let reason = viewModel.lastSwitchReason {
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
}

private struct StatusSettingsSection: View {
    let viewModel: SettingsViewModel
    
    var body: some View {
        if let message = viewModel.statusMessage {
            Section {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(viewModel.statusIsError ? .red : .secondary)
            }
        }
    }
}
