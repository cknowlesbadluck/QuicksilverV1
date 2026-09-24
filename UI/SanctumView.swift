import SwiftUI
import Core

/// The Sanctum — Quicksilver's spatial home.
///
/// An environment, not a dashboard. Destinations are places inside the domain.
/// The Brain remains authoritative for VisualState and aspect.
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
        .onAppear { viewModel?.startLiveRefresh() }
        .onDisappear { viewModel?.stopLiveRefresh() }
        .sheet(isPresented: $showAsk) {
            NavigationStack { AskView() }
                .preferredColorScheme(.dark)
        }
        .fullScreenCover(item: $destination) { selected in
            destinationView(selected)
        }
    }

    @ViewBuilder
    private func destinationView(_ selected: SpatialDestination) -> some View {
        RealmGateway(
            title: selected.title,
            personaID: personaID(for: selected),
            isPresented: binding(for: selected)
        ) {
            switch selected {
            case .workshop: ForgeView()
            case .planetarium: EternalView()
            case .archive: MemoryView()
            case .codex: CodexView()
            case .diagnostics: DiagnosticsView()
            }
        }
    }

    private func personaID(for selected: SpatialDestination) -> String {
        switch selected {
        case .workshop: return Aspect.forge.rawValue
        case .planetarium: return Aspect.eternal.rawValue
        case .archive, .codex, .diagnostics: return Aspect.quicksilver.rawValue
        }
    }

    private func binding(for target: SpatialDestination) -> Binding<Bool> {
        Binding(
            get: { destination == target },
            set: { if !$0 { destination = nil } }
        )
    }
}
