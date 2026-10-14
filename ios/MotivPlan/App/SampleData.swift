import CoreModels
import Foundation
import SwiftData
import TimelineEngine

/// Données d'exemple pour les captures d'écran automatiques de la CI.
enum SampleData {
    static let launchArgument = "-ui-testing"

    static func seed(into context: ModelContext) {
        let store = TaskStore(context: context, settings: AppSettings())
        // Réglages éphémères : chaque lancement de test refait sections et report.
        guard let volatile = UserDefaults(suiteName: "ui-testing.\(UUID().uuidString)") else { return }
        do {
            try store.ensureDefaultSections(defaults: volatile)
            let sections = Dictionary(uniqueKeysWithValues: try store.sections().map { ($0.name, $0) })
            let today = store.today

            // À trier : captures récentes, pas encore rangées.
            let plumber = try store.capture("Appeler le plombier", source: .siri)
            try store.setDueDate(DayKeys.adding(-2, to: today), of: plumber)
            try store.setTag(.urgent, of: plumber)
            let passport = try store.capture("Renouveler le passeport", source: .manual)
            try store.setNotes("Photo d'identité + justificatif de domicile.", of: passport)
            try store.capture("Lire l'article sur le sommeil", source: .widget)

            func add(_ title: String, to section: String, tag: TaskTag? = nil) throws -> TaskItem {
                let task = try store.capture(title, source: .manual)
                try store.setSection(sections[section], of: task)
                if let tag { try store.setTag(tag, of: task) }
                return task
            }

            // Quotidiennes : posées seules aujourd'hui.
            let bed = try add("Faire le lit", to: "Quotidiennes", tag: .medium)
            _ = try add("Vider la litière de Stella", to: "Quotidiennes", tag: .medium)

            // Récurrentes : toujours disponibles, avec la dernière fois.
            let laundry = try add("Faire une lessive", to: "Récurrentes")
            try store.toggleDone(laundry)
            _ = try add("Descendre les poubelles", to: "Récurrentes")

            // Ponctuelles, planifiées aujourd'hui avec une ancre.
            let report = try add("Finir le rapport trimestriel", to: "Ponctuelles", tag: .travail)
            try store.setDueDate(store.endOfThisWeek, of: report)
            try store.setDuration(90, of: report)
            try store.schedule(report, on: today)
            let bank = try add("Appeler la banque", to: "Ponctuelles", tag: .urgent)
            try store.schedule(bank, on: today)
            let meeting = try add("Point d'équipe", to: "Ponctuelles", tag: .travail)
            try store.setDuration(45, of: meeting)
            try store.schedule(meeting, on: today)
            try store.setAnchor(11 * 60 + 15, of: meeting)
            let sport = try add("Sport", to: "Ponctuelles", tag: .detente)
            try store.setDuration(45, of: sport)
            try store.schedule(sport, on: today)
            _ = try add("Envoyer le courrier", to: "Ponctuelles")
            try store.toggleDone(bed)

            // Hors planning, avec mémoire.
            _ = try add("Lait d'avoine", to: "Courses")
            _ = try add("Café en grains", to: "Courses")
            _ = try add("The Bear, saison 3", to: "Films et séries", tag: .detente)
            _ = try add("Dune, deuxième partie", to: "Films et séries", tag: .detente)
            let seen = try add("Past Lives", to: "Films et séries")
            try store.complete(seen, review: .aime, note: "Tout en retenue, très beau.")
            let meh = try add("Rebel Moon", to: "Films et séries")
            try store.complete(meh, review: .pasAime, note: nil)
            let curry = try add("Curry de lentilles corail", to: "Recettes")
            try store.complete(curry, review: .aime, note: "Ajouter du citron vert à la fin.")

            // Reste de la semaine, pour la vue Semaine.
            if let tomorrow = DayKeys.adding(1, to: today), let later = DayKeys.adding(3, to: today) {
                let bankFile = try add("Préparer le dossier banque", to: "Ponctuelles", tag: .travail)
                try store.schedule(bankFile, on: tomorrow)
                let dinner = try add("Dîner chez Paul", to: "Ponctuelles", tag: .detente)
                try store.setDuration(120, of: dinner)
                try store.schedule(dinner, on: tomorrow)
                try store.setAnchor(20 * 60, of: dinner)
                let garage = try add("Passer au garage", to: "Ponctuelles", tag: .urgent)
                try store.schedule(garage, on: later)
            }

            // Restes d'hier : reportés en silence au lancement (ADR-007).
            if let yesterday = DayKeys.adding(-1, to: today) {
                let contract = try add("Relire le contrat", to: "Ponctuelles", tag: .travail)
                try store.setDuration(30, of: contract)
                try store.schedule(contract, on: yesterday)
                let dentist = try add("Rendez-vous dentiste", to: "Ponctuelles")
                try store.schedule(dentist, on: yesterday)
                try store.setAnchor(17 * 60, of: dentist)
            }
            try store.rollover(defaults: volatile)
        } catch {
            assertionFailure("Données d'exemple : \(error)")
        }
    }
}
