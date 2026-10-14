import AppIntents
import CoreModels
import SwiftData
import SwiftUI

@main
struct MotivPlanApp: App {
    private let provider: StoreProvider
    @State private var captureRequested = false

    init() {
        // Les tests d'interface lancent l'app avec un store en mémoire et des données d'exemple.
        let uiTesting = ProcessInfo.processInfo.arguments.contains(SampleData.launchArgument)
        let provider = StoreProvider(inMemory: uiTesting)
        self.provider = provider
        if uiTesting, let container = provider.container {
            SampleData.seed(into: container.mainContext)
        }
        // Seule chose garantie quand Siri lance l'app en arrière-plan : App.init (plan, §Architecture).
        AppDependencyManager.shared.add(dependency: { provider })
    }

    var body: some Scene {
        WindowGroup {
            switch provider.result {
            case .success(let container):
                RootView(captureRequested: $captureRequested)
                    .onOpenURL { url in
                        if url.scheme == AppGroup.urlScheme, url.host() == "capture" {
                            captureRequested = true
                        }
                    }
                    .modelContainer(container)
            case .failure:
                StoreUnavailableView()
            }
        }
    }
}
