import SwiftUI
import Core

struct AskView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: AskViewModel?

    var body: some View {
        let personaID = container.activeConfiguration.id
        let accent = PersonaTheme.accent(for: personaID)

        ZStack {
            PersonaTheme.voidBlack.ignoresSafeArea()
            AmbientLayer(
                personaID: personaID,
                visualState: viewModel?.isProcessing == true ? .thinking : .idle
            )

            Group {
                if let vm = viewModel {
                    content(vm, personaID: personaID, accent: accent)
                } else {
                    ProgressView()
                        .tint(accent)
                        .onAppear { viewModel = AskViewModel(container: container) }
                }
            }
        }
        .navigationTitle("Invocation")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(PersonaTheme.voidBlack, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ vm: AskViewModel, personaID: String, accent: Color) -> some View {
        let bubble = PersonaTheme.assistantBubbleStyle(for: personaID)
        let radius = PersonaTheme.cardCornerRadius(for: personaID)

        VStack(spacing: 0) {
            headerBar(vm, personaID: personaID, accent: accent, radius: radius)
            conversationScrollView(vm, personaID: personaID, accent: accent, bubble: bubble, radius: radius)
            inputBar(vm, personaID: personaID, accent: accent, radius: radius)
        }
        .task { await vm.loadHistory() }
    }

    @ViewBuilder
    private func headerBar(_ vm: AskViewModel, personaID: String, accent: Color, radius: CGFloat) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)

            Text(container.activeConfiguration.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(PersonaTheme.mercurySilver)

            Spacer()

            Text("PROVIDER: \(vm.providerName.uppercased())")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.45))
        .overlay(
            Rectangle()
                .fill(accent.opacity(0.18))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func conversationScrollView(
        _ vm: AskViewModel,
        personaID: String,
        accent: Color,
        bubble: (opacity: Double, weight: Font.Weight),
        radius: CGFloat
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(vm.turns) { turn in
                        turnBubble(turn, personaID: personaID, accent: accent, assistantOpacity: bubble.opacity, assistantWeight: bubble.weight, radius: radius)
                            .id(turn.id)
                    }

                    if let error = vm.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
                        )
                    }
                }
                .padding(16)
            }
            .onChange(of: vm.turns.count) { _, _ in
                if let last = vm.turns.last?.id {
                    withAnimation(MotionTokens.spring(for: personaID)) {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func inputBar(_ vm: AskViewModel, personaID: String, accent: Color, radius: CGFloat) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(accent.opacity(0.2))
                .frame(height: 1)

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Invoke \(container.activeConfiguration.displayName)…", text: Binding(
                    get: { vm.draft },
                    set: { vm.draft = $0 }
                ), axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.42))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius * 0.7, style: .continuous)
                        .strokeBorder(accent.opacity(0.28), lineWidth: 1)
                )

                Button {
                    Task { await vm.submit() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(accent)
                            .frame(width: 38, height: 38)
                            .shadow(color: accent.opacity(0.5), radius: 6)

                        if vm.isProcessing {
                            ProgressView()
                                .tint(PersonaTheme.voidBlack)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(PersonaTheme.voidBlack)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing)
                .opacity(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isProcessing ? 0.45 : 1.0)
            }
            .padding(14)
            .background(.ultraThinMaterial.opacity(0.55))
        }
    }

    private func turnBubble(
        _ turn: ChatTurn,
        personaID: String,
        accent: Color,
        assistantOpacity: Double,
        assistantWeight: Font.Weight,
        radius: CGFloat
    ) -> some View {
        HStack {
            if turn.role == .user { Spacer(minLength: 36) }

            VStack(alignment: turn.role == .user ? .trailing : .leading, spacing: 4) {
                Text(turn.role == .user ? "YOU" : container.activeConfiguration.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(turn.role == .user ? accent.opacity(0.85) : PersonaTheme.mercurySilver.opacity(0.55))

                Text(turn.text)
                    .font(.subheadline.weight(turn.role == .assistant ? assistantWeight : .regular))
                    .foregroundStyle(PersonaTheme.mercuryBright)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial.opacity(turn.role == .user ? 0.35 : 0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                turn.role == .user
                                    ? accent.opacity(0.40)
                                    : PersonaTheme.radioactiveStroke(for: personaID),
                                lineWidth: 1
                            )
                    )
            }

            if turn.role == .assistant { Spacer(minLength: 36) }
        }
    }
}
