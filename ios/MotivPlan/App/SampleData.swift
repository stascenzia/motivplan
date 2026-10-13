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
        } catch {
            assertionFailure("Données d'exemple : \(error)")
        }
    }
}
