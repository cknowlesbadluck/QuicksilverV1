import SwiftUI
import Core

/// Quicksilver is not summoned. He is already here.
/// Permanent ambient presence in the Sanctum — no card chrome.
struct QuicksilverPresenceView: View {
    let personaID: String
    let chamber: SanctumChamber
    let livingStatus: String
    var visualState: VisualState = .idle

    var body: some View {
        VStack(spacing: 20) {
            QuicksilverCoreView(
                personaID: personaID,
                chamber: chamber,
                visualState: visualState,
                size: 80
            )

            VStack(spacing: 6) {
                Text(presenceTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PersonaTheme.mercurySilver)

                Text(livingStatus)
                    .font(.subheadline)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
