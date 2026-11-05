import CoreModels
import SwiftUI

/// Valise archivée par « Voyage fini » : l'inventaire du voyage, rangé par catégorie, avec ses
/// coches telles qu'elles étaient au retour.
struct PackingCard: View {
    let task: TaskItem
    let store: TaskStore
    let run: (() throws -> Void) -> Void

    @State private var checkCount = 0

    var body: some View {
        let items = task.subtasks
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                CardTitle(text: "Valise")
                Spacer()
                Text("\(items.filter(\.isDone).count) sur \(items.count) cochés")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            ForEach(PackingCategory.all, id: \.self) { category in
                let inCategory = items.filter { PackingCategory.of($0) == category }
                if !inCategory.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category)
                            .font(.manrope(13, .extrabold, relativeTo: .footnote))
                            .foregroundStyle(Palette.textSecondary)
                        ForEach(inCategory) { item in
                            SubtaskRow(subtask: item) {
                                run { try store.toggleSubtask(item.id, of: task) }
                                checkCount += 1
                            }
                        }
                    }
                }
            }
        }
        .card()
        .sensoryFeedback(.selection, trigger: checkCount)
    }
}

/// Champ « Ajouter dans Vêtements… » d'une catégorie de valise : valider garde le clavier pour
/// enchaîner les articles.
struct SuitcaseAddField: View {
    let category: String
    let add: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 26, height: 26)
            TextField("Ajouter dans \(category)…", text: $text)
                .font(.manrope(15, .medium, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .focused($focused)
                .submitLabel(.next)
                .onSubmit(submit)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }
    }

    private func submit() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        add(title)
        text = ""
        focused = true
    }
}
