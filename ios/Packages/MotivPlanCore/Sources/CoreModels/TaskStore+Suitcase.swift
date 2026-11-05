import Foundation
import SwiftData

/// Liste de valise (modèle `valise`) : les articles de la section sont l'inventaire du voyage en
/// cours, rangés par catégorie. Un article coché le reste (aller), on le décoche au retour.
/// « Voyage fini » range tout l'inventaire dans une archive datée et vide la liste pour le
/// prochain voyage. Pas de changement de schéma : la catégorie et la marque d'archive vivent dans
/// les champs (`fieldsRaw`), l'inventaire archivé dans les sous-tâches.
extension TaskStore {
    public static let categoryField = "category"
    public static let archiveField = "archive"

    /// Ajoute un article dans une catégorie de la valise.
    @discardableResult
    public func addSuitcaseItem(_ title: String, category: String, to section: TaskSection) throws -> TaskItem {
        let item = try capture(title, source: .manual)
        try setSection(section, of: item)
        try setField(Self.categoryField, to: category, of: item)
        return item
    }

    public func setCategory(_ category: String, of item: TaskItem) throws {
        try setField(Self.categoryField, to: category, of: item)
    }

    /// Archive l'inventaire du voyage : une entrée terminée, datée, qui garde chaque article avec
    /// sa catégorie et sa coche ; les articles quittent la liste. `nil` si la liste est vide.
    @discardableResult
    public func finishTrip(_ section: TaskSection) throws -> TaskItem? {
        let articles = (try tasks(in: section) + memory(of: section)).filter { !$0.isSuitcaseArchive }
        guard !articles.isEmpty else { return nil }
        let order = PackingCategory.all
        let sorted = articles.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.packingCategory) ?? order.count
            let right = order.firstIndex(of: rhs.packingCategory) ?? order.count
            return left != right ? left < right : lhs.createdAt < rhs.createdAt
        }
        let stamp = now()
        let date = stamp.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
        let archive = try capture("Voyage du \(date)", source: .manual)
        try setSection(section, of: archive)
        archive.subtasksRaw = Self.encode(sorted.map {
            Subtask(title: $0.title, isDone: $0.status == .done, category: $0.packingCategory)
        })
        archive.fieldsRaw = Self.encode(fields: [Self.archiveField: "1"])
        archive.statusRaw = TaskStatus.done.rawValue
        archive.completedAt = stamp
        touch(archive)
        for article in articles {
            article.deletedAt = stamp
            touch(article)
        }
        try save()
        return archive
    }
}

extension TaskItem {
    /// Inventaire archivé par « Voyage fini ».
    public var isSuitcaseArchive: Bool { field(TaskStore.archiveField) == "1" }

    /// Catégorie d'un article de valise ; sans catégorie connue, la dernière (« Divers »).
    public var packingCategory: String {
        guard let category = field(TaskStore.categoryField), PackingCategory.all.contains(category) else {
            return PackingCategory.fallback
        }
        return category
    }
}
