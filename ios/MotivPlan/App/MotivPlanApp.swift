import AppIntents
import BackgroundTasks
import CoreModels
import SwiftData
import SwiftUI
import SyncClient
import UIKit

@main
struct MotivPlanApp: App {
    private let provider: StoreProvider
    private let sync: SyncCoordinator?
    @State private var captureRequested = false

    init() {
        // Les tests d'interface lancent l'app avec un store en mémoire et des données d'exemple.
        let uiTesting = ProcessInfo.processInfo.arguments.contains(SampleData.launchArgument)
        let provider = StoreProvider(inMemory: uiTesting)
        self.provider = provider
        if uiTesting, let container = provider.container {
            SampleData.seed(into: container.mainContext)
            // Sans animations, le testeur lit l'écran sans attendre qu'il se stabilise (CI lente).
            UIView.setAnimationsEnabled(false)
        }
        // Pas de synchro pendant les tests d'interface.
        sync = provider.container.map { container in
            uiTesting ? SyncCoordinator(container: container, makeTransport: { nil }) : SyncCoordinator(container: container)
        }
        sync?.start()
        // Seule chose garantie quand Siri lance l'app en arrière-plan : App.init (plan, §Architecture).
        AppDependencyManager.shared.add(dependency: { provider })
    }

    var body: some Scene {
        let sync = self.sync
        WindowGroup {
            Group {
                switch provider.result {
                case .success(let container):
                    RootView(captureRequested: $captureRequested)
                        .onOpenURL { url in
                            if url.scheme == AppGroup.urlScheme, url.host() == "capture" {
                                captureRequested = true
                            }
                        }
                        .modelContainer(container)
                        .environment(sync)
                case .failure:
                    StoreUnavailableView()
                }
            }
            // Les maquettes n'existent qu'en sombre (docs/design-etude.md) ; Info.plist force aussi le style.
            .preferredColorScheme(.dark)
            .tint(Palette.accent)
        }
        .backgroundTask(.appRefresh(SyncBackground.identifier)) {
            SyncBackground.schedule()
            await sync?.syncNow()
        }
    }
}

/// Rafraîchissement d'arrière-plan : iOS choisit le moment, au plus tôt une heure après la demande.
nonisolated enum SyncBackground {
    static let identifier = "fr.ascenzia.motivplan.sync"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
