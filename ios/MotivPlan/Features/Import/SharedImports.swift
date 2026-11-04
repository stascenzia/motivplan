import CoreModels
import Foundation
import MemoryImport
import SwiftData

/// Recettes partagées depuis une autre app (Picnic, Safari, Photos) par l'extension « MotivPlan »
/// (ADR-017). L'extension dépose une fiche dans l'App Group ; l'app la lit au passage au premier
/// plan et la range dans la première section Recettes, à relire depuis sa fiche.
@MainActor
enum SharedImports {
    private static var running = false

    static var queue: PendingImportQueue? {
        PendingImportQueue(groupContainer: AppGroup.isAvailable
            ? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)
            : nil)
    }

    /// Nombre de recettes créées.
    @discardableResult
    static func importPending(into context: ModelContext) async -> Int {
        guard !running, let queue else { return 0 }
        let items = queue.pending()
        guard !items.isEmpty else { return 0 }
        running = true
        defer { running = false }
        let store = TaskStore(context: context)
        let section = try? store.sections().first { $0.template == .recette }
        var created = 0
        for item in items {
            let draft = await draft(for: item, queue: queue, section: section?.id)
            if let task = try? store.create(draft) {
                for url in queue.imageURLs(of: item) {
                    if let data = try? Data(contentsOf: url) { try? PhotoStore.add(data, to: task.id) }
                }
                created += 1
            }
            queue.remove(item)
        }
        return created
    }

    private static func draft(for item: PendingImport, queue: PendingImportQueue, section: UUID?) async -> TaskDraft {
        var lines: [String] = []
        for url in queue.imageURLs(of: item) {
            if let data = try? Data(contentsOf: url) {
                lines += (try? await TextRecognition.lines(in: data)) ?? []
            }
        }
        var recipe = RecipeParser.parse(lines: lines)
        var title = recipe.title
        let link = item.url ?? item.text.flatMap(webLink)
        if let link, let url = URL(string: link), recipe.isEmpty, let page = await fetch(url) {
            if let parsed = page.recipe { recipe = parsed }
            title = page.title ?? title
        }
        if recipe.isEmpty, let text = item.text, text != link {
            let parsed = RecipeParser.parse(text)
            recipe = parsed.isEmpty ? recipe : parsed
            title = title ?? parsed.title ?? text.components(separatedBy: .newlines).first
        }
        var fields = RecipeFields.values(of: recipe)
        if let link { fields[RecipeFields.source] = link }
        let fallback = link.flatMap { URL(string: $0)?.host() } ?? "Recette partagée"
        return TaskDraft(title: (title ?? recipe.title).flatMap(nonEmpty) ?? fallback, sectionId: section,
                         space: .memory, fields: fields)
    }

    /// Un texte qui n'est qu'un lien.
    private static func webLink(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("http"), !trimmed.contains(" "), URL(string: trimmed) != nil else { return nil }
        return trimmed
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(120))
    }

    /// Page de la recette : sa description schema.org si elle en a une. Hors ligne, rien.
    private static func fetch(_ url: URL) async -> WebRecipe? {
        guard url.scheme == "https" || url.scheme == "http" else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("fr-FR,fr;q=0.9", forHTTPHeaderField: "Accept-Language")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return nil }
        return WebRecipeExtractor.extract(html: html)
    }
}
