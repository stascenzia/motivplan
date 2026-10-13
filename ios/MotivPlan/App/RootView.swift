import SwiftUI

/// Racine provisoire : la boîte de réception. Vues Jour et Semaine aux lots 3 et 6.
struct RootView: View {
    @Binding var captureRequested: Bool

    var body: some View {
        NavigationStack {
            InboxView(captureRequested: $captureRequested)
                .toolbar {
                    #if DEBUG
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink {
                            SpikeView()
                        } label: {
                            Image(systemName: "waveform")
                        }
                        .accessibilityLabel("Spike Siri")
                    }
                    #endif
                }
        }
    }
}
