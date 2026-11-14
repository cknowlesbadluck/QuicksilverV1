import Combine
import SwiftUI
import UIKit

@main
struct QuicksilverApp: App {
    @State private var container = DependencyContainer()
    @State private var energy = AmbientEnergy.current

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            SanctumView()
                .environment(container)
                .preferredColorScheme(.dark)
                // Decorative motion slows in Low Power Mode / thermal pressure (AmbientEnergy).
                .environment(\.ambientEnergy, energy)
                .onReceive(energyChanges) { _ in energy = .current }
                // First unlock after boot: Keychain becomes readable, so rebuild cloud routes.
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.protectedDataDidBecomeAvailableNotification
                )) { _ in container.aiService.rehydrateProvidersIfNeeded() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        container.nexus.start()
                        energy = .current
                        Task { await container.noteSpotlight.sync() } // keeps the index matching notes and the opt-in
                    case .background:
                        container.nexus.stop()
                        container.aiService.releaseOnDeviceResources() // M3.5-T4: don't hold a warm session in background
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    container.aiService.releaseOnDeviceResources() // M3.5-T4: memory pressure drops the warm session
                }
        }
    }

    /// Low Power Mode and thermal changes, delivered on the main queue.
    private var energyChanges: AnyPublisher<Void, Never> {
        Publishers.Merge(
            NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange),
            NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
        )
        .map { _ in () }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
