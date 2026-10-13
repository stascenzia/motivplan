import SwiftUI

/// Onglets : Jour et Boîte de réception. Semaine au lot 6.
struct RootView: View {
    @Binding var captureRequested: Bool

    private enum Tab: Hashable { case day, inbox }
    @State private var tab: Tab = .day

    var body: some View {
        TabView(selection: $tab) {
            DayScreen()
                .tabItem { Label("Jour", systemImage: "sun.max") }
                .tag(Tab.day)

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
            .tabItem { Label("Boîte", systemImage: "tray") }
            .tag(Tab.inbox)
        }
        // Le widget ouvre la boîte de réception, champ de capture actif.
        .onChange(of: captureRequested, initial: true) { _, requested in
            if requested { tab = .inbox }
        }
    }
}
