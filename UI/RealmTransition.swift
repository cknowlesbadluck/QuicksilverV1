import SwiftUI
import Core

/// Spatial realm transition foundation.
/// Full choreography is iterative; this provides consistent enter/exit motion and Reduce Motion safety.
enum RealmTransition {
    static var spatial: Animation { MotionTokens.realmTransition }
    static var reduced: Animation { MotionTokens.reduced(MotionTokens.realmTransition) }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : spatial
    }
}

/// Applies a persona-aware transition to a view hierarchy.
struct RealmTransitionModifier: ViewModifier {
    let personaID: String
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .transition(transition)
            .animation(RealmTransition.animation(reduceMotion: reduceMotion), value: personaID)
    }

    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch personaID.lowercased() {
        case "forge":
            return .asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        case "eternal":
            return .asymmetric(
                insertion: .scale(scale: 0.92).combined(with: .opacity),
                removal: .scale(scale: 1.04).combined(with: .opacity)
            )
        default:
            return .opacity
        }
    }
}

extension View {
    func realmTransition(personaID: String, reduceMotion: Bool) -> some View {
        modifier(RealmTransitionModifier(personaID: personaID, reduceMotion: reduceMotion))
    }
}

/// Full-screen cover style gateway for a realm — preferred over plain sheet long-term.
struct RealmGateway<Content: View>: View {
    let title: String
    let personaID: String
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            content()
                .realmTransition(personaID: personaID, reduceMotion: reduceMotion)
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
