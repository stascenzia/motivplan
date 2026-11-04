import CoreModels
import SwiftData
import SwiftUI
import SyncClient
import WidgetKit

/// Coque de l'app : Planning, Boîte, Mémoire, Calendrier, et la création au centre de la barre.
///
/// Seul l'écran choisi existe : la barre est masquée dès qu'un écran est poussé, on ne change
/// donc jamais d'onglet au milieu d'une navigation. Le jour affiché est gardé ici.
struct RootView: View {
    @Binding var deepLink: DeepLink?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var sync: SyncCoordinator?
    @Query(TaskItem.inboxDescriptor) private var inbox: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]

    @State private var chrome = AppChrome()
    @State private var tab: AppTab = .planning
    @State private var day = DayKeys.key(for: .now)
    @State private var capture: CaptureRequest?
    @State private var newTask: NewTaskRequest?
    /// Liste ouverte dans l'onglet Mémoire : le « + » y range la nouvelle entrée.
    @State private var memorySection: UUID?

    var body: some View {
        Group {
            switch tab {
            case .planning:
                DayScreen(day: $day)
            case .inbox:
                NavigationStack { InboxView() }
            case .memory:
                MemoryScreen(selection: $memorySection)
            case .calendar:
                WeekScreen { opened in
                    day = opened
                    tab = .planning
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // La barre flotte par-dessus le contenu ; chaque écran garde la place en bas
        // (TabBarMetrics.contentInset), et le tiroir replié se pose au-dessus.
        .overlay(alignment: .bottom) {
            if !chrome.isTabBarHidden {
                FloatingTabBar(selection: $tab, inboxBadge: inbox.filter(\.isUnsortedTask).count) {
                    newTask = defaultRequest
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: chrome.isTabBarHidden)
        .environment(chrome)
        .screenBackground()
        .fullScreenCover(item: $capture) { request in
            CaptureScreen(source: request.source, space: request.space)
        }
        .sheet(item: $newTask) { request in
            NewTaskSheet(initialSection: request.section, initialSpace: request.space)
                .presentationDragIndicator(.visible)
        }
        // Les widgets ouvrent la capture (clavier levé, source « widget »), la journée ou le calendrier.
        .onChange(of: deepLink, initial: true) { _, link in
            guard let link else { return }
            switch link {
            case .capture(let space):
                capture = CaptureRequest(source: .widget, space: space)
            case .today:
                day = DayKeys.key(for: .now)
                tab = .planning
            case .calendar:
                tab = .calendar
            }
            deepLink = nil
        }
        // Report silencieux à la première ouverture après minuit (ADR-007) : ni écran ni notification.
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                let store = TaskStore(context: context)
                try? store.ensureDefaultSections()
                _ = try? store.rollover()
                refreshWidgets()
                // Synchro au passage au premier plan, après le report (plan, §Synchronisation).
                Task { await sync?.syncNow() }
            case .inactive:
                refreshWidgets()
            case .background:
                SyncBackground.schedule()
            default:
                break
            }
        }
    }

    /// Créée dans l'app, une entrée est rangée d'office (ADR-015) : dans la liste ouverte de l'onglet
    /// Mémoire, sinon dans la première section ponctuelle planifiable.
    private var defaultRequest: NewTaskRequest {
        if tab == .memory {
            if memorySection == MemoryScreen.unsortedSelection { return NewTaskRequest(section: nil, space: .memory) }
            let open = memorySection.flatMap { id in sections.first { $0.id == id && $0.kind.isMemorySpace } }
            return NewTaskRequest(section: (open ?? sections.first { $0.kind.isMemorySpace })?.id, space: .memory)
        }
        return NewTaskRequest(section: sections.first { $0.isDayPlannable && $0.repeatRule == .none }?.id, space: .tasks)
    }

    /// Instantané des widgets d'affichage (lot 14), rechargés seulement si la semaine a changé.
    private func refreshWidgets() {
        guard let snapshot = try? TaskStore(context: context).widgetSnapshot() else { return }
        let previous = WidgetSnapshot.load()
        guard previous?.days != snapshot.days || previous?.periods != snapshot.periods else { return }
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.todayWidgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.weekWidgetKind)
    }
}

/// Liens `motivplan://` ouverts par les widgets.
enum DeepLink: Equatable {
    case capture(TaskSpace)
    case today
    case calendar

    init?(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return nil }
        switch url.host() {
        case "capture":
            let space = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "space" }?.value
            self = .capture(space == TaskSpace.memory.rawValue ? .memory : .tasks)
        case "today":
            self = .today
        case "calendar":
            self = .calendar
        default:
            return nil
        }
    }
}

/// Ouverture de la création complète (bouton « + »).
struct NewTaskRequest: Identifiable {
    let id = UUID()
    let section: UUID?
    var space: TaskSpace = .tasks
}

/// Ouverture de l'écran de capture, avec la source à enregistrer.
struct CaptureRequest: Identifiable {
    let id = UUID()
    let source: TaskSource
    var space: TaskSpace = .tasks
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
