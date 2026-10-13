import AppIntents
import CoreModels
import Foundation

// Spike Siri hors-ligne du lot 0 (ADR-003). Écrit dans les UserDefaults de l'App Group,
// sans SwiftData. Remplacé par AddTaskIntent dans CoreIntents au lot 4.

// nonisolated : appelé depuis perform(), qui ne tourne pas sur le MainActor. UserDefaults est thread-safe.
nonisolated enum SpikeLog {
    private static let key = "spike.captures"

    static func append(_ title: String) {
        var entries = all()
        entries.append("\(Date.now.formatted(date: .omitted, time: .standard)) · \(title)")
        AppGroup.defaults.set(entries, forKey: key)
    }

    static func all() -> [String] {
        AppGroup.defaults.stringArray(forKey: key) ?? []
    }

    static func clear() {
        AppGroup.defaults.removeObject(forKey: key)
    }
}

struct SpikeAddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Ajouter une tâche"
    static let description = IntentDescription("Ajoute une tâche dans la boîte de réception.")

    @Parameter(title: "Tâche", requestValueDialog: IntentDialog("Quelle tâche ?"))
    var taskTitle: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .result(dialog: "Rien à ajouter.")
        }
        SpikeLog.append(trimmed)
        return .result(dialog: "Ajouté : \(trimmed)")
    }
}

struct MotivPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SpikeAddTaskIntent(),
            phrases: [
                "Ajoute une tâche dans \(.applicationName)",
                "Nouvelle tâche \(.applicationName)",
            ],
            shortTitle: "Ajouter une tâche",
            systemImageName: "plus.circle"
        )
    }
}
