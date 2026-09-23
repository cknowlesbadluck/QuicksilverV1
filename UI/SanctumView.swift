import SwiftUI
import Core

/// The Sanctum — Quicksilver's spatial home.
///
/// The Sanctum is an environment, not a dashboard. Destinations are places
/// inside Quicksilver's domain; the Brain remains authoritative for state and
/// aspect selection.
struct SanctumView: View {
    @Environment(DependencyContainer.self) private var container
    @State private var viewModel: SanctumViewModel?
    @State private var destination: SpatialDestination?
    @State private var showAsk = false

    var body: some View {
        Group {
            if let viewModel {
                SpatialSanctum(
                    visualState: viewModel.visualState,
                    activeAspect: viewModel.activeAspect,
                    livingStatus: viewModel.livingStatus,
                    onDestination: { destination = $0 },
                    onInvoke: { showAsk = true }
                )
            } else {
                PersonaTheme.voidBlack
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel = SanctumViewModel(container: container)
                    }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel?.startLiveRefresh()
        }
        .onDisappear {
            viewModel?.stopLiveRefresh()
        }
        .sheet(isPresented: $showAsk) {
            NavigationStack { AskView() }
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $destination) { destination in
            destinationView(destination)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: SpatialDestination) -> some View {
        switch destination {
        case .workshop:
            RealmGateway(
                title: "The Workshop",
                personaID: Aspect.forge.rawValue,
                isPresented: Binding(
                    get: { self.destination == .workshop },
                    set: { if !$0 { self.destination = nil } }
                )
            ) {
                ForgeView()
            }

        case .planetarium:
            RealmGateway(
                title: "The Planetarium",
                personaID: Aspect.eternal.rawValue,
                isPresented: Binding(
                    get: { self.destination == .planetarium },
                    set: { if !$0 { self.destination = nil } }
                )
            ) {
                EternalView()
            }

        case .archive:
            NavigationStack {
                MemoryView()
            }
            .preferredColorScheme(.dark)

        case .codex:
            NavigationStack {
                CodexView()
            }
            .preferredColorScheme(.dark)

        case .diagnostics:
            NavigationStack {
                DiagnosticsView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
