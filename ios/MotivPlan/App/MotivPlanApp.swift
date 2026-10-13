import CoreModels
import SwiftData
import SwiftUI

@main
struct MotivPlanApp: App {
    private let container: ModelContainer
    @State private var captureRequested = false

    init() {
        // Les tests d'interface lancent l'app avec un store en mémoire et des données d'exemple.
        let uiTesting = ProcessInfo.processInfo.arguments.contains(SampleData.launchArgument)
        do {
            container = try Persistence.makeContainer(inMemory: uiTesting)
        } catch {
            fatalError("Store SwiftData inaccessible : \(error)")
        }
        if uiTesting {
            SampleData.seed(into: container.mainContext)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(captureRequested: $captureRequested)
                .onOpenURL { url in
                    if url.scheme == AppGroup.urlScheme, url.host() == "capture" {
                        captureRequested = true
                    }
                }
        }
        .modelContainer(container)
    }
}
