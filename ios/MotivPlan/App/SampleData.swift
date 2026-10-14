import CoreModels
import SwiftData
import TimelineEngine

/// Données d'exemple pour les captures d'écran automatiques de la CI.
enum SampleData {
    static let launchArgument = "-ui-testing"

    static func seed(into context: ModelContext) {
        let store = TaskStore(context: context, settings: AppSettings())
        do {
            let plumber = try store.capture("Appeler le plombier", source: .siri)
            try store.setDueDate(DayKeys.adding(-2, to: store.today), of: plumber)
            try store.setImportance(.haute, of: plumber)

            let report = try store.capture("Finir le rapport trimestriel", source: .manual)
            try store.setCategory(.pro, of: report)
            try store.setDueDate(store.endOfThisWeek, of: report)

            let gifts = try store.capture("Idées de cadeaux pour Noël", source: .widget)
            try store.setCategory(.courte, of: gifts)

            try store.capture("Lire l'article sur le sommeil", source: .manual)

            let passport = try store.capture("Renouveler le passeport", source: .manual)
            try store.setCategory(.moyenne, of: passport)
            try store.setNotes("Photo d'identité + justificatif de domicile.", of: passport)

            // Journée d'aujourd'hui : une tâche faite, une ancre qui pousse une flottante.
            let today = store.today
            let plan: [(String, TaskCategory, Int)] = [
                ("Trier les mails", .quotidienne, 30),
                ("Préparer la présentation", .longue, 90),
                ("Appeler la banque", .courte, 30),
                ("Sport", .moyenne, 45),
            ]
            for (title, category, minutes) in plan {
                let task = try store.capture(title, source: .manual)
                try store.setCategory(category, of: task)
                try store.setDuration(minutes, of: task)
                try store.schedule(task, on: today)
            }
            let meeting = try store.capture("Point d'équipe", source: .manual)
            try store.setCategory(.pro, of: meeting)
            try store.setDuration(45, of: meeting)
            try store.schedule(meeting, on: today)
            try store.setAnchor(11 * 60 + 15, of: meeting)
            let lunch = try store.capture("Déjeuner avec Léa", source: .manual)
            try store.setDuration(60, of: lunch)
            try store.schedule(lunch, on: today)
            try store.setAnchor(13 * 60, of: lunch)
            if let first = try store.tasks(on: today).first(where: { $0.title == "Trier les mails" }) {
                try store.toggleDone(first)
            }

            // Restes d'hier : reportés en silence au lancement (ADR-007).
            if let yesterday = DayKeys.adding(-1, to: today) {
                let contract = try store.capture("Relire le contrat", source: .manual)
                try store.setDuration(30, of: contract)
                try store.schedule(contract, on: yesterday)
                let dentist = try store.capture("Rendez-vous dentiste", source: .manual)
                try store.schedule(dentist, on: yesterday)
                try store.setAnchor(17 * 60, of: dentist)
            }
            // Réglages éphémères : chaque lancement de test refait le report.
            if let volatile = UserDefaults(suiteName: "ui-testing.\(UUID().uuidString)") {
                try store.rollover(defaults: volatile)
            }
        } catch {
            assertionFailure("Données d'exemple : \(error)")
        }
    }
}
