import CoreModels
import SwiftUI

/// Valise d'un voyage : un inventaire rangé par catégorie (Vêtements, Sac à dos, Divers).
/// À l'aller on coche ce qu'on emporte, les articles restent cochés ; au retour on décoche ce qu'on
/// a bien rapporté. « Voyage fini » archive la valise ; elle se rouvre depuis les archives.
struct PackingCard: View {
    let task: TaskItem
    let store: TaskStore
    let run: (() throws -> Void) -> Void
    /// Valise seule : rouvrir depuis les archives. Un voyage se rouvre depuis sa carte Mémoire.
    var reopens = true
    /// « Voyage fini » : archive la valise, ou ouvre l'avis d'un voyage.
    let finish: () -> Void

    @State private var drafts: [String: String] = [:]
    @State private var checkCount = 0
    @FocusState private var adding: String?

    var body: some View {
        let items = task.subtasks
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardTitle(text: "Valise")
                Spacer()
                if !items.isEmpty {
                    Text("\(items.filter(\.isDone).count) sur \(items.count) cochés")
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            ForEach(PackingCategory.all, id: \.self) { category in
                categoryBlock(category, items: items.filter { PackingCategory.of($0) == category })
            }
            if task.isDone {
                if reopens {
                    Button("Rouvrir la valise") { run { try store.toggleDone(task) } }
                        .buttonStyle(PillButtonStyle())
                }
            } else {
                Button("Voyage fini", action: finish)
                .buttonStyle(PillButtonStyle(prominent: true))
                .accessibilityHint("Archive la valise")
            }
        }
        .card()
        .sensoryFeedback(.selection, trigger: checkCount)
    }

    private func categoryBlock(_ category: String, items: [Subtask]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category)
                .font(.manrope(13, .extrabold, relativeTo: .footnote))
                .foregroundStyle(Palette.textSecondary)
            ForEach(items) { item in
                SubtaskRow(subtask: item) {
                    run { try store.toggleSubtask(item.id, of: task) }
                    checkCount += 1
                }
                .contextMenu {
                    Button("Retirer", systemImage: "trash", role: .destructive) {
                        run { try store.deleteSubtask(item.id, of: task) }
                    }
                }
            }
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 22, height: 22)
                TextField("Ajouter dans \(category)…", text: Binding(
                    get: { drafts[category, default: ""] },
                    set: { drafts[category] = $0 }
                ))
                .font(.manrope(15, .medium, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .focused($adding, equals: category)
                .submitLabel(.next)
                .onSubmit { add(to: category) }
            }
            .frame(minHeight: 40)
        }
    }

    /// Valider garde le clavier pour enchaîner les articles.
    private func add(to category: String) {
        let title = drafts[category, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        run { _ = try store.addSubtask(title, category: category, to: task) }
        drafts[category] = ""
        adding = category
    }
}
