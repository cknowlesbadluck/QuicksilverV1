import SwiftUI
import Core

/// Quicksilver is not an icon or status badge. The living core is his persistent presence.
/// The surrounding interface remains quiet enough for the mercury to carry the visual identity.
struct QuicksilverPresenceView: View {
    let personaID: String
    let livingStatus: String
    var visualState: VisualState = .idle

    var body: some View {
        VStack(spacing: 14) {
            QuicksilverCoreView(
                personaID: personaID,
                visualState: visualState,
                size: 104
            )
            .frame(height: 246)
            .contentShape(Rectangle())

            VStack(spacing: 6) {
                Text(presenceTitle)
                    .font(.title3.weight(.semibold))
                    .tracking(0.45)
                    .foregroundStyle(PersonaTheme.mercurySilver)

                Text(livingStatus)
                    .font(.subheadline)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .animation(PersonaTheme.spring(for: personaID), value: personaID)
        .animation(MotionTokens.stabilization, value: visualState)
    }

    private var presenceTitle: String {
        switch personaID.lowercased() {
        case "forge": return "Forge is awake"
        case "eternal": return "Eternal observes"
        default: return "Quicksilver"
        }
    }
}
