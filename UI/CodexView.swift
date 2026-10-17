import SwiftUI
import Core

/// The Codex — governance of Mercury himself.
/// Not a settings screen. The user is altering the fundamental laws.
struct CodexView: View {
    @Environment(DependencyContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: CodexViewModel?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let vm = viewModel {
                codexContent(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = CodexViewModel(container: container) }
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
    private func codexContent(_ vm: CodexViewModel) -> some View {
        Form {
            mindSection(vm)
            Section {
                Toggle("Show notes in Spotlight", isOn: Binding(
                    get: { vm.spotlightNotesEnabled },
                    set: { vm.setSpotlightNotes($0) }
                ))
                .accessibilityIdentifier("codex.spotlightNotes")
            } footer: {
                Text("Off by default. Only saved notes, never conversations. Turning it off removes them from search.")
            }
            gatewaySection(vm)
            covenantSection(vm)

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
        // On-device availability can change in Settings while the Codex is open.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.refresh() }
        }
    }

    @ViewBuilder
    private func mindSection(_ vm: CodexViewModel) -> some View {
        Section {
            Toggle("Intelligence Active", isOn: Binding(
                get: { vm.aiEnabled },
                set: { vm.setAIEnabled($0) }
            ))
            LabeledContent("Vessel", value: vm.providerName)
            LabeledContent(
                "Bound",
                value: boundSummary(vm)
            )
            LabeledContent("On-device mind", value: vm.onDeviceStatus)
                .accessibilityHint(vm.onDeviceReason ?? "")
            LabeledContent("Answers via", value: vm.answerRoute)
            if let budget = vm.cloudBudgetLabel {
                LabeledContent("Cloud budget", value: budget)
            }
            LabeledContent("Policy route", value: vm.activeRouteLabel)
            LabeledContent("Policy model", value: vm.activeModelLabel)
        } header: {
            Text("Mind")
        } footer: {
            Text("Credentials remain sealed in the device Keychain. They never leave the device in logs or defaults.")
        }

        Section {
            if vm.recentRoutes.isEmpty {
                Text("No turns yet this session")
                    .foregroundStyle(PersonaTheme.readableSecondary)
            } else {
                ForEach(vm.recentRoutes) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.summary)
                        Text(record.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(PersonaTheme.readableSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Recent routes")
        } footer: {
            Text("Which route each recent turn took and why. No prompts or replies are stored, and this clears on relaunch.")
        }
    }

    @ViewBuilder
    private func gatewaySection(_ vm: CodexViewModel) -> some View {
        Section {
            TextField("Gateway URL (https)", text: Binding(
                get: { vm.gatewayURLDraft },
                set: { vm.gatewayURLDraft = $0 }
            ))
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            SecureField("Device token", text: Binding(
                get: { vm.gatewayTokenDraft },
                set: { vm.gatewayTokenDraft = $0 }
            ))
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

            Button("Bind Gateway") {
                vm.bindGateway()
            }
            .disabled(
                vm.gatewayURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || vm.gatewayTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

            Button {
                Task { await vm.testGatewayConnection() }
            } label: {
                if vm.isTestingGateway {
                    ProgressView()
                } else {
                    Text("Test connection")
                }
            }
            .disabled(
                vm.isTestingGateway
                    || (vm.gatewayURLDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && !vm.hasGatewayBinding)
            )

            LabeledContent(
                "Gateway",
                value: vm.hasGatewayBinding
                    ? "Bound — \(vm.gatewayURLDisplay)"
                    : "Unbound"
            )
            if vm.hasGatewayBinding {
                Button("Unbind Gateway", role: .destructive) {
                    vm.unbindGateway()
                }
            }
        } header: {
            Text("Mercury Gateway")
        } footer: {
            Text("Bind the owner-run Workers gateway with an https URL and device token. Test hits GET /v1/health. Interim Gemini/Grok keys below remain until M3-T22.")
        }
    }

    @ViewBuilder
    private func covenantSection(_ vm: CodexViewModel) -> some View {
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

            LabeledContent(
                "Routing",
                value: vm.fallbackProviderName.map { "\(vm.providerName) / \($0)" } ?? vm.providerName
            )

            Button("Remove all provider keys", role: .destructive) {
                container.aiService.clearAllAPIKeys()
                vm.refresh()
            }
        } header: {
            Text("Covenant")
        } footer: {
            Text("Gemini free-tier key is the interim cloud bind. Grok is optional. Prefer the Mercury Gateway section above.")
        }
    }

    private func boundSummary(_ vm: CodexViewModel) -> String {
        if vm.hasGatewayBinding { return "Yes — Gateway" }
        if vm.hasGrokKey || vm.hasGeminiKey { return "Yes — Keychain" }
        return "Unbound"
    }
}
