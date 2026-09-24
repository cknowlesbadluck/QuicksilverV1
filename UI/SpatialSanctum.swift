import SwiftUI
import Core

/// Spatial destinations inside Quicksilver's domain.
/// Places and instruments — not separate assistants or products.
enum SpatialDestination: String, CaseIterable, Identifiable {
    case workshop
    case planetarium
    case archive
    case codex
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workshop: return "The Workshop"
        case .planetarium: return "The Planetarium"
        case .archive: return "The Archive"
        case .codex: return "The Codex"
        case .diagnostics: return "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .workshop: return "Forge"
        case .planetarium: return "Eternal"
        case .archive: return "Memory"
        case .codex: return "Governance"
        case .diagnostics: return "Under the hood"
        }
    }

    var symbol: String {
        switch self {
        case .workshop: return "flame"
        case .planetarium: return "sparkles"
        case .archive: return "books.vertical"
        case .codex: return "scroll"
        case .diagnostics: return "waveform.path.ecg"
        }
    }

    var accent: Color {
        switch self {
        case .workshop: return PersonaTheme.accent(for: Aspect.forge.rawValue)
        case .planetarium: return PersonaTheme.accent(for: Aspect.eternal.rawValue)
        case .archive: return PersonaTheme.mercurySilver
        case .codex: return PersonaTheme.secondaryAccent(for: Aspect.quicksilver.rawValue)
        case .diagnostics: return PersonaTheme.mercuryBright
        }
    }

    var quip: String {
        switch self {
        case .workshop: return "Finally. Something worth making."
        case .planetarium: return "Careful. Eternal is watching."
        case .archive: return "Let's see what I've managed to remember."
        case .codex: return "Ah. The rules. Everyone's favorite."
        case .diagnostics: return "You want to look underneath? Fine."
        }
    }
}

/// First spatial layer of the Sanctum.
/// 2.5D SwiftUI composition — not a game-engine scene.
struct SpatialSanctum: View {
    let visualState: VisualState
    let activeAspect: Aspect
    let livingStatus: String
    let onDestination: (SpatialDestination) -> Void
    let onInvoke: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showGreeting = false
    @State private var orbit: Double = 0

    private var accent: Color { PersonaTheme.accent(for: activeAspect.rawValue) }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MercurySanctumBackdrop(accent: accent)
                    .ignoresSafeArea()

                AmbientLayer(
                    personaID: activeAspect.rawValue,
                    visualState: visualState
                )

                spatialArchitecture(in: proxy.size)

                VStack(spacing: 0) {
                    topPresence
                    Spacer()

                    QuicksilverPresenceView(
                        personaID: activeAspect.rawValue,
                        livingStatus: livingStatus,
                        visualState: visualState
                    )
                    .onTapGesture { onInvoke() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Speak with Quicksilver")

                    Spacer()
                    navigationPrompt
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)

                if showGreeting {
                    greeting
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.96))
                        )
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                showGreeting = true
                if !reduceMotion {
                    withAnimation(MotionTokens.celestialOrbit) {
                        orbit = 360
                    }
                }
            }
        }
        .animation(MotionTokens.spring(for: activeAspect.rawValue), value: activeAspect)
        .animation(MotionTokens.stabilization, value: visualState)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quicksilver's Sanctum")
    }

    private var topPresence: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
                .shadow(color: accent.opacity(0.8), radius: 4)

            Text("SANCTUM")
                .font(.caption.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.82))

            Text("·")
                .foregroundStyle(.tertiary)

            Text(visualState.rawValue.uppercased())
                .font(.caption2.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.55))

            Spacer()

            Button(action: onInvoke) {
                Image(systemName: "bubble.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.72))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak with Quicksilver")
        }
    }

    private var greeting: some View {
        VStack(spacing: 7) {
            Text(greetingTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PersonaTheme.mercurySilver)

            Text(greetingPrompt)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.66))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 30)
        .offset(y: -118)
    }

    private var greetingTitle: String {
        switch visualState {
        case .sleeping:
            return "Oh. You're back."
        case .thinking, .processing:
            return "Give me a moment."
        default:
            return "Oh. You again."
        }
    }

    private var greetingPrompt: String {
        if !livingStatus.isEmpty && livingStatus != "Quicksilver is present." {
            return livingStatus
        }
        return "What are we getting into?"
    }

    private var navigationPrompt: some View {
        HStack(spacing: 6) {
            ForEach(SpatialDestination.allCases) { destination in
                SpatialPortalButton(destination: destination) {
                    onDestination(destination)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mercury realms")
    }

    private func spatialArchitecture(in size: CGSize) -> some View {
        ZStack {
            Circle()
                .stroke(
                    PersonaTheme.mercurySilver.opacity(0.08),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 12])
                )
                .frame(
                    width: min(size.width * 1.45, 650),
                    height: min(size.width * 1.45, 650)
                )
                .rotationEffect(.degrees(orbit))

            portalHalo(.workshop, x: 0.12, y: 0.36, size: size)
            portalHalo(.planetarium, x: 0.86, y: 0.29, size: size)
            portalHalo(.archive, x: 0.88, y: 0.67, size: size)
            portalHalo(.codex, x: 0.18, y: 0.72, size: size)
            portalHalo(.diagnostics, x: 0.50, y: 0.17, size: size)
        }
        .allowsHitTesting(false)
    }

    private func portalHalo(
        _ destination: SpatialDestination,
        x: CGFloat,
        y: CGFloat,
        size: CGSize
    ) -> some View {
        let radius: CGFloat = destination == .diagnostics ? 74 : 58
        return Circle()
            .fill(destination.accent.opacity(0.035))
            .overlay {
                Circle()
                    .stroke(destination.accent.opacity(0.10), lineWidth: 1)
            }
            .frame(width: radius, height: radius)
            .position(x: size.width * x, y: size.height * y)
    }
}

private struct SpatialPortalButton: View {
    let destination: SpatialDestination
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(destination.accent.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: destination.symbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(destination.accent.opacity(0.92))
                }

                Text(destination.title.replacingOccurrences(of: "The ", with: ""))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(destination.subtitle)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(destination.title)
        .accessibilityHint(destination.subtitle + ". " + destination.quip)
    }
}
