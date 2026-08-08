import SwiftUI
import Core

/// Spatial realm transition foundation.
/// Full choreography (glyph → energy → gateway → emerge) is iterative;
/// this provides consistent enter/exit motion and Reduce Motion safety.
enum RealmTransition {
    /// Primary spring for realm change when motion is allowed.
    static var spatial: Animation { MotionTokens.realmTransition }

    /// Calm cross-fade when Reduce Motion is enabled.
    static var reduced: Animation { MotionTokens.reduced(MotionTokens.realmTransition) }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : spatial
    }
}

/// Applies a realm-aware transition to a view hierarchy.
struct RealmTransitionModifier: ViewModifier {
    let chamber: SanctumChamber
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .transition(transition)
            .animation(RealmTransition.animation(reduceMotion: reduceMotion), value: chamber)
    }

    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch chamber {
        case .forge:
            // Forge rises from below — workshop ascending
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case .eternal:
            // Eternal expands from depth — observatory opening
            return .asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .scale(scale: 1.04).combined(with: .opacity)
            )
        case .sanctum:
            return .opacity
        }
    }
}

extension View {
    func realmTransition(chamber: SanctumChamber, reduceMotion: Bool) -> some View {
        modifier(RealmTransitionModifier(chamber: chamber, reduceMotion: reduceMotion))
    }
}

/// Full-screen cover style gateway for a realm — preferred over plain sheet long-term.
struct RealmGateway<Content: View>: View {
    let title: String
    let chamber: SanctumChamber
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            content()
                .realmTransition(chamber: chamber, reduceMotion: reduceMotion)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            withAnimation(RealmTransition.animation(reduceMotion: reduceMotion)) {
                                isPresented = false
                            }
                        }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}
