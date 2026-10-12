import CoreModels
import SwiftUI

@main
struct MotivPlanApp: App {
    @State private var captureRequested = false

    var body: some Scene {
        WindowGroup {
            SpikeView(captureRequested: $captureRequested)
                .onOpenURL { url in
                    if url.scheme == AppGroup.urlScheme, url.host() == "capture" {
                        captureRequested = true
                    }
                }
        }
    }
}
