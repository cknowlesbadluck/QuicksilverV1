import SwiftUI
import ServicesAI
import Core

struct AskView: View {
    private static let unboundNoticeID = "ask.unboundNotice"
    private static let errorMessageID = "ask.errorMessage"
    private static let onDeviceReasonID = "ask.onDeviceReason"

    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: AskViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
            } else {
                ProgressView()
                    .onAppear { viewModel = AskViewModel(container: container) }
            }
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ vm: AskViewModel) -> some View {
        let personaID = container.activeConfiguration.id
        let accent = PersonaTheme.accent(for: personaID)
        let bubble = PersonaTheme.assistantBubbleStyle(for: personaID)

        VStack(spacing: 0) {
            conversationScrollView(vm, accent: accent, bubble: bubble)
            Divider()
            inputBar(vm, accent: accent)
        }
        .task { await vm.loadHistory() }
    }

    @ViewBuilder
    private func conversationScrollView(
        _ vm: AskViewModel,
        accent: Color,
        bubble: (opacity: Double, weight: Font.Weight)
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Text("Provider: \(vm.providerName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(vm.turns) { turn in
                        turnBubble(turn, accent: accent, assistantOpacity: bubble.opacity, assistantWeight: bubble.weight)
                            .id(turn.id)
                    }

                    if let notice = vm.unboundNotice {
                        Text(notice)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accent)
                            .accessibilityLabel(notice)
                            .id(Self.unboundNoticeID)
                        if let reason = vm.onDeviceReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("ask.onDeviceReason")
                                .id(Self.onDeviceReasonID)
                        }
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .id(Self.errorMessageID)
                    }
                }
                .padding()
            }
            .onChange(of: vm.turns.count) { _, _ in
                if let last = vm.turns.last?.id {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.unboundNotice) { _, notice in
                guard notice != nil else { return }
                withAnimation {
                    proxy.scrollTo(vm.onDeviceReason == nil ? Self.unboundNoticeID : Self.onDeviceReasonID, anchor: .bottom)
                }
            }
            .onChange(of: vm.errorMessage) { _, error in
                guard error != nil else { return }
                withAnimation {
                    proxy.scrollTo(Self.errorMessageID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func inputBar(_ vm: AskViewModel, accent: Color) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Go on. Impress me.", text: Binding(
                get: { vm.draft },
                set: { vm.draft = $0 }
            ), axis: .vertical)
            .lineLimit(1...4)
            .textFieldStyle(.roundedBorder)

            Button {
                Task { await vm.submit() }
            } label: {
                if vm.isProcessing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(accent)
                }
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
        }
        .padding()
    }

    private func turnBubble(
        _ turn: ChatTurn,
        accent: Color,
        assistantOpacity: Double,
        assistantWeight: Font.Weight
    ) -> some View {
        HStack {
            if turn.role == .user { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                Text(turn.text)
                    .font(.body.weight(turn.role == .assistant ? assistantWeight : .regular))
                    .padding(12)
                    .background(
                        turn.role == .user
                            ? accent.opacity(0.18)
                            : Color.secondary.opacity(assistantOpacity),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                if let provenance = turn.provenance {
                    Label(provenance.badge, systemImage: Self.symbol(for: provenance.origin))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(provenance.accessibilityLabel)
                        .accessibilityIdentifier("ask.provenance")
                }
            }
            if turn.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private static func symbol(for origin: AnswerProvenance.Origin) -> String {
        switch origin {
        case .onDevice: "iphone"
        case .cloud: "cloud"
        case .memory: "brain"
        }
    }
}
