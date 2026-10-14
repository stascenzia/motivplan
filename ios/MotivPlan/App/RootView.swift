import CoreModels
import SwiftUI

/// Onglets : Jour et Boîte de réception. Semaine au lot 6.
struct RootView: View {
    @Binding var captureRequested: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    private enum Tab: Hashable { case day, inbox }
    @State private var tab: Tab = .day

    var body: some View {
        TabView(selection: $tab) {
            DayScreen()
                .tabItem { Label("Jour", systemImage: "sun.max") }
                .tag(Tab.day)

            NavigationStack {
                InboxView(captureRequested: $captureRequested)
            }
            .tabItem { Label("Boîte", systemImage: "tray") }
            .tag(Tab.inbox)
        }
        // Le widget ouvre la boîte de réception, champ de capture actif.
        .onChange(of: captureRequested, initial: true) { _, requested in
            if requested { tab = .inbox }
        }
        // Report silencieux à la première ouverture après minuit (ADR-007) : ni écran ni notification.
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                _ = try? TaskStore(context: context).rollover()
            }
        }
    }
}

/// Store illisible : cas rare, avant le premier déverrouillage après un redémarrage.
struct StoreUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "MotivPlan n'est pas encore accessible",
            systemImage: "lock",
            description: Text("Déverrouille ton iPhone, puis rouvre l'app. Tes tâches sont intactes."))
    }
}
