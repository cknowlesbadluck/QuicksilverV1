import SwiftUI
import Core
import Personas

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
        case .planetarium: return "Tread softly. I remember everything here."
        case .archive: return "Let's see what I've managed to remember."
        case .codex: return "Ah. The rules. Everyone's favorite."
        case .diagnostics: return "You want to look underneath? Fine."
        }
    }
}

/// The Sanctum as a cosmological field.
/// Realms are bodies in space. There is no destination grid and no status chrome.
struct SpatialSanctum: View {
    let visualState: VisualState
    let activeAspect: Aspect
    let livingStatus: String
    let onDestination: (SpatialDestination) -> Void
    let onInvoke: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showGreeting = false
    @State private var orbit: Double = 0
    @State private var fieldPhase: Double = 0

    private var accent: Color { PersonaTheme.accent(for: activeAspect.rawValue) }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                MercurySanctumBackdrop(accent: accent)
                    .ignoresSafeArea()

                AmbientLayer(
                    personaID: activeAspect.rawValue,
                    visualState: visualState
                )

                fieldRings(in: size)

                ForEach(SanctumFieldLayout.anchors) { anchor in
                    let point = SanctumFieldLayout.point(
                        for: anchor,
                        phase: fieldPhase,
                        size: size,
                        reduceMotion: reduceMotion
                    )
                    SpatialPortal(
                        destination: anchor.destination,
                        depth: anchor.depth
                    ) {
                        onDestination(anchor.destination)
                    }
                    .position(point)
                }

                presence(in: size)

                if showGreeting {
                    inscription
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                showGreeting = true
                guard !reduceMotion else { return }
                withAnimation(MotionTokens.celestialOrbit) {
                    orbit = 360
                }
                withAnimation(MotionTokens.fieldDrift) {
                    fieldPhase = 1
                }
            }
        }
        .animation(MotionTokens.spring(for: activeAspect.rawValue), value: activeAspect)
        .animation(MotionTokens.stabilization, value: visualState)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quicksilver's Sanctum")
    }

    private func presence(in size: CGSize) -> some View {
        QuicksilverPresenceView(
            personaID: activeAspect.rawValue,
            livingStatus: livingStatus,
            visualState: visualState
        )
        .frame(width: min(size.width * 0.62, 280))
        .position(
            x: size.width * PersonaTheme.sanctumCoreX,
            y: size.height * PersonaTheme.sanctumCoreY
        )
        .onTapGesture { onInvoke() }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Speak with Quicksilver")
        .accessibilityHint(livingStatus)
    }

    private var inscription: some View {
        Text(greetingTitle)
            .font(.title3.weight(.medium))
            .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.88))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 36)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 28)
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

    private func fieldRings(in size: CGSize) -> some View {
        ZStack {
            Ellipse()
                .stroke(
                    PersonaTheme.mercurySilver.opacity(0.07),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 14])
                )
                .frame(width: size.width * 0.92, height: size.height * 0.62)
                .rotationEffect(.degrees(orbit * 0.15))

            Ellipse()
                .stroke(
                    accent.opacity(0.10),
                    style: StrokeStyle(lineWidth: 0.7, dash: [10, 18])
                )
                .frame(width: size.width * 0.70, height: size.height * 0.42)
                .rotationEffect(.degrees(-orbit * 0.08))
        }
        .position(
            x: size.width * PersonaTheme.sanctumCoreX,
            y: size.height * PersonaTheme.sanctumCoreY
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SpatialPortal: View {
    let destination: SpatialDestination
    let depth: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(destination.accent.opacity(0.55), lineWidth: 1)
                        .background(
                            Circle().fill(destination.accent.opacity(0.08 + (0.08 * depth)))
                        )
                        .frame(
                            width: PersonaTheme.sanctumPortalHit * 0.72,
                            height: PersonaTheme.sanctumPortalHit * 0.72
                        )

                    Image(systemName: destination.symbol)
                        .font(.body.weight(.medium))
                        .foregroundStyle(destination.accent)
                }

                Text(destination.title.replacingOccurrences(of: "The ", with: ""))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.82))
                    .lineLimit(1)
            }
            .frame(
                width: PersonaTheme.sanctumPortalHit,
                height: PersonaTheme.sanctumPortalHit + 16
            )
            .scaleEffect(PersonaTheme.sanctumPortalScale(depth: depth))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(destination.title)
        .accessibilityHint(destination.subtitle + ". " + destination.quip)
    }
}
