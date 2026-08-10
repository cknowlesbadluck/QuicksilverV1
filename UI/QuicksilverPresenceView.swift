import SwiftUI
import Core

/// Quicksilver is not summoned. He is already here.
/// Permanent ambient presence in the Sanctum — no card chrome.
struct QuicksilverPresenceView: View {
    let personaID: String
    let chamber: SanctumChamber
    let livingStatus: String
    var visualState: VisualState = .idle

    private var accent: Color {
        PersonaTheme.accent(for: personaID)
    }

    var body: some View {
        VStack(spacing: 18) {
            MercuryPresenceOrb(accent: accent, size: 132)

            VStack(spacing: 7) {
                Text(presenceTitle)
                    .font(.title3.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(PersonaTheme.mercurySilver)

                Text(livingStatus)
                    .font(.subheadline)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .animation(PersonaTheme.spring(for: personaID), value: chamber)
    }

    private var presenceTitle: String {
        switch chamber {
        case .forge:
            return "Forge is awake"
        case .eternal:
            return "Eternal observes"
        case .sanctum:
            return "Quicksilver"
        }
    }
}
