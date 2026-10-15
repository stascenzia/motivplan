import CoreModels
import SwiftData
import SwiftUI
import SyncClient

/// Coque de l'app : Planning, Boîte, Calendrier, et la capture au centre de la barre.
///
/// Les trois écrans restent vivants côte à côte (seul le choisi est visible) : chacun garde
/// sa navigation et son défilement quand on change d'onglet, sans la barre système.
struct RootView: View {
    @Binding var captureRequested: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var sync: SyncCoordinator?
    @Query(TaskItem.inboxDescriptor) private var inbox: [TaskItem]

    @State private var chrome = AppChrome()
    @State private var tab: AppTab = .planning
    @State private var day = DayKeys.key(for: .now)
    @State private var capture: CaptureRequest?

    var body: some View {
        ZStack {
            screen(.planning) { DayScreen(day: $day) }
            screen(.inbox) { NavigationStack { InboxView() } }
            screen(.calendar) {
                WeekScreen { opened in
                    day = opened
                    tab = .planning
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !chrome.isTabBarHidden {
                FloatingTabBar(selection: $tab, inboxBadge: inbox.filter { $0.sectionId == nil }.count) {
                    capture = CaptureRequest(source: .manual)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: chrome.isTabBarHidden)
        .environment(chrome)
        .screenBackground()
        .fullScreenCover(item: $capture) { request in
            CaptureScreen(source: request.source)
        }
        // Le widget ouvre la capture, clavier levé, source « widget ».
        .onChange(of: captureRequested, initial: true) { _, requested in
            guard requested else { return }
            capture = CaptureRequest(source: .widget)
            captureRequested = false
        }
        // Report silencieux à la première ouverture après minuit (ADR-007) : ni écran ni notification.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                let store = TaskStore(context: context)
                try? store.ensureDefaultSections()
                _ = try? store.rollover()
                // Synchro au passage au premier plan, après le report (plan, §Synchronisation).
                Task { await sync?.syncNow() }
            case .background:
                SyncBackground.schedule()
            default:
                break
            }
        }
    }

    private func screen<Content: View>(_ value: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let visible = tab == value
        return content()
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
            .zIndex(visible ? 1 : 0)
    }
}

/// Ouverture de l'écran de capture, avec la source à enregistrer.
struct CaptureRequest: Identifiable {
    let id = UUID()
    let source: TaskSource
}

/// Store illisible : cas rare, avant le premier déverrouillage après un redémarrage.
struct StoreUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "MotivPlan n'est pas encore accessible",
            systemImage: "lock",
            description: Text("Déverrouille ton iPhone, puis rouvre l'app. Tes tâches sont intactes."))
            .screenBackground()
    }
}
