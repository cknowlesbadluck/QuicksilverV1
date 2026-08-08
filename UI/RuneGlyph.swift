import SwiftUI

/// Functional glyph — memory, diagnostics, network, creation, observation, etc.
/// Not wallpaper. Activation should cause environmental response.
enum GlyphKind: String, CaseIterable, Identifiable, Sendable {
    case memory
    case diagnostics
    case network
    case communication
    case security
    case development
    case observation
    case creation
    case intelligence
    case configuration
    case health

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .memory: return "brain.head.profile"
        case .diagnostics: return "waveform.path.ecg"
        case .network: return "antenna.radiowaves.left.and.right"
        case .communication: return "bubble.left.and.bubble.right"
        case .security: return "lock.shield"
        case .development: return "hammer"
        case .observation: return "eye"
        case .creation: return "flame"
        case .intelligence: return "sparkles"
        case .configuration: return "slider.horizontal.3"
        case .health: return "heart.circle"
        }
    }

    var label: String {
        switch self {
        case .memory: return "Memory"
        case .diagnostics: return "Diagnostics"
        case .network: return "Network"
        case .communication: return "Invoke"
        case .security: return "Security"
        case .development: return "Forge"
        case .observation: return "Observe"
        case .creation: return "Create"
        case .intelligence: return "Mind"
        case .configuration: return "Codex"
        case .health: return "Health"
        }
    }
}

enum GlyphVisualState: String, Sendable {
    case idle
    case attention
    case active
    case warning
    case disabled
}

/// A single functional rune in the Sanctum / realm environment.
struct RuneGlyph: View {
    let kind: GlyphKind
    var state: GlyphVisualState = .idle
    var personaID: String = "quicksilver"
    var action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    @State private var glowPulse = false

    private var accent: Color {
        switch state {
        case .warning: return Color(red: 0.95, green: 0.35, blue: 0.2)
        case .active: return PersonaTheme.accent(for: personaID)
        case .attention: return PersonaTheme.secondaryAccent(for: personaID)
        case .disabled: return PersonaTheme.mercurySilver.opacity(0.25)
        case .idle: return PersonaTheme.mercurySilver.opacity(0.55)
        }
    }

    var body: some View {
        Button {
            guard state != .disabled else { return }
            withAnimation(MotionTokens.glyphActivation) {
                pressed = true
            }
            action?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(MotionTokens.glyphActivation) {
                    pressed = false
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    // Outer activation ring
                    Circle()
                        .strokeBorder(accent.opacity(ringOpacity), lineWidth: 1)
                        .frame(width: 52, height: 52)
                        .scaleEffect(pressed ? 1.12 : (glowPulse && state == .active ? 1.06 : 1.0))

                    // Inner well
                    Circle()
                        .fill(PersonaTheme.voidBlack.opacity(0.55))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .strokeBorder(accent.opacity(0.35), lineWidth: 0.8)
                        )

                    Image(systemName: kind.systemImage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accent)
                        .symbolEffect(.bounce, value: pressed)
                }

                Text(kind.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(state == .disabled ? 0.3 : 0.7))
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .disabled)
        .accessibilityLabel(kind.label)
        .accessibilityAddTraits(state == .active ? .isSelected : [])
        .onAppear {
            guard !reduceMotion, state == .active || state == .attention else { return }
            withAnimation(MotionTokens.energyPulse) {
                glowPulse = true
            }
        }
    }

    private var ringOpacity: Double {
        switch state {
        case .active: return 0.7
        case .attention: return 0.5
        case .warning: return 0.8
        case .idle: return 0.25
        case .disabled: return 0.1
        }
    }
}

/// Horizontal or flowing row of glyphs for Sanctum / realm instrument strips.
struct GlyphStrip: View {
    let glyphs: [(GlyphKind, GlyphVisualState)]
    var personaID: String = "quicksilver"
    var onActivate: ((GlyphKind) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(glyphs, id: \.0.id) { kind, state in
                    RuneGlyph(
                        kind: kind,
                        state: state,
                        personaID: personaID
                    ) {
                        onActivate?(kind)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
