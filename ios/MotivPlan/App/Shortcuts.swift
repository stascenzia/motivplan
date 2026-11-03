import AppIntents
import CoreIntents

/// Les intents vivent dans CoreIntents ; l'app les inclut et déclare les phrases Siri.
struct MotivPlanAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [CoreIntentsPackage.self] }
}

/// Phrases sans paramètre : une phrase ne peut pas porter de texte libre (ADR-003).
/// Siri demande ensuite « Quelle tâche ? ».
///
/// Aucun mot des domaines système (« note », « tâche », « rappel », « liste », « ajoute ») : testé
/// sur l'iPhone, « Note dans MotivPlan » part vers Notes, « Ajoute à MotivPlan » vers Rappels.
struct MotivPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "\(.applicationName) capture",
                "Capture dans \(.applicationName)",
                "Dépose dans \(.applicationName)",
                "Ouvre la boîte \(.applicationName)",
            ],
            shortTitle: "Capturer",
            systemImageName: "plus.circle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .teal }
}
