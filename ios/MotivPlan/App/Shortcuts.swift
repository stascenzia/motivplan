import AppIntents
import CoreIntents

/// Les intents vivent dans CoreIntents ; l'app les inclut et déclare les phrases Siri.
struct MotivPlanAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [CoreIntentsPackage.self] }
}

/// Phrases sans paramètre : une phrase ne peut pas porter de texte libre (ADR-003).
/// Siri demande ensuite « Quelle tâche ? ».
struct MotivPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Ajoute une tâche dans \(.applicationName)",
                "Nouvelle tâche \(.applicationName)",
                "Note dans \(.applicationName)",
            ],
            shortTitle: "Ajouter une tâche",
            systemImageName: "plus.circle"
        )
    }

    static var shortcutTileColor: ShortcutTileColor { .teal }
}
