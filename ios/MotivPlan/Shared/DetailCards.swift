import CoreModels
import SwiftUI

/// Sous-tâches d'une tâche existante (ADR-016) : cocher, ajouter, retirer, déplacer.
/// Cocher toutes les étapes ne termine pas la tâche : on la coche soi-même.
struct SubtasksCard: View {
    let task: TaskItem
    let store: TaskStore
    let run: (() throws -> Void) -> Void

    @State private var newTitle = ""
    @State private var checkCount = 0
    @FocusState private var adding: Bool

    var body: some View {
        let subtasks = task.subtasks
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                CardTitle(text: "Étapes")
                Spacer()
                if let progress = SubtaskLabel.progress(subtasks) {
                    Text(progress)
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            ForEach(Array(subtasks.enumerated()), id: \.element.id) { index, subtask in
                SubtaskRow(subtask: subtask) {
                    run { try store.toggleSubtask(subtask.id, of: task) }
                    checkCount += 1
                }
                .contextMenu {
                    if index > 0 {
                        Button("Monter", systemImage: "arrow.up") { run { try store.moveSubtask(subtask.id, to: index - 1, of: task) } }
                    }
                    if index < subtasks.count - 1 {
                        Button("Descendre", systemImage: "arrow.down") { run { try store.moveSubtask(subtask.id, to: index + 1, of: task) } }
                    }
                    Button("Retirer", systemImage: "trash", role: .destructive) { run { try store.deleteSubtask(subtask.id, of: task) } }
                }
            }
            AddStepField(text: $newTitle, focus: $adding) { title in
                run { try store.addSubtask(title, to: task) }
            }
        }
        .card()
        .sensoryFeedback(.selection, trigger: checkCount)
    }
}

/// Sous-tâches d'une tâche en création (bouton « + ») : simples titres, dans l'ordre.
struct DraftSubtasksCard: View {
    @Binding var titles: [String]

    @State private var newTitle = ""
    @FocusState private var adding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardTitle(text: "Étapes")
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                HStack(spacing: 12) {
                    Circle()
                        .strokeBorder(Palette.ring, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    Text(title)
                        .font(.manrope(15, .semibold, relativeTo: .body))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        titles.remove(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.textTertiary)
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retirer « \(title) »")
                }
                .frame(minHeight: 40)
            }
            AddStepField(text: $newTitle, focus: $adding) { title in
                titles.append(title)
            }
        }
        .card()
    }
}

/// Répétition de la planification (ADR-018) : passé son jour, faite ou non, la tâche se replanifie
/// seule sur sa prochaine date.
struct RepeatCard: View {
    let rule: TaskRepeat?
    let choose: (TaskRepeat?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardTitle(text: "Répétition")
            FlowLayout(spacing: 6) {
                ChoiceChip(label: "Aucune", selected: rule == nil) { choose(nil) }
                ForEach(TaskRepeat.allCases, id: \.self) { value in
                    ChoiceChip(label: value.label, selected: rule == value) { choose(value) }
                }
            }
            Text(rule == nil ? "Une fois faite, la tâche est terminée."
                             : "Une fois son jour passé, elle se replanifie seule. Planifie-la pour lancer la série.")
                .font(.meta)
                .foregroundStyle(Palette.textTertiary)
        }
        .card()
    }
}

/// Ligne d'une étape : rond à cocher et titre, barré une fois fait.
struct SubtaskRow: View {
    let subtask: Subtask
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                ZStack {
                    if subtask.isDone {
                        Circle().fill(Palette.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Palette.onAccent)
                    } else {
                        Circle().strokeBorder(Palette.ring, lineWidth: 2)
                    }
                }
                .frame(width: 22, height: 22)
                Text(subtask.title)
                    .font(.manrope(15, .semibold, relativeTo: .body))
                    .strikethrough(subtask.isDone)
                    .foregroundStyle(subtask.isDone ? Palette.textMuted : Palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(subtask.isDone ? .isSelected : [])
    }
}

/// Champ « Ajouter une étape… » : valider garde le clavier pour enchaîner.
private struct AddStepField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    let add: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 22, height: 22)
            TextField("Ajouter une étape…", text: $text)
                .font(.manrope(15, .medium, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .focused(focus)
                .submitLabel(.next)
                .onSubmit(submit)
                .accessibilityIdentifier("subtask-field")
        }
        .frame(minHeight: 40)
    }

    private func submit() {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        add(title)
        text = ""
        focus.wrappedValue = true
    }
}

/// Champs propres au modèle d'une section (ADR-016). `immediate` : chaque frappe est transmise
/// (feuille de création) ; sinon, le texte part en quittant le champ (fiche enregistrée).
struct TemplateFieldsCard: View {
    let fields: [TemplateField]
    let values: [String: String]
    var immediate = false
    let commit: (String, String?) -> Void

    @State private var drafts: [String: String] = [:]
    @State private var customField: String?
    @State private var customText = ""
    @State private var choicesVersion = 0
    @FocusState private var focused: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(fields.filter { field in field.showsWhen.map { drafts[$0.key] == $0.value } ?? true }) { field in
                VStack(alignment: .leading, spacing: 8) {
                    CardTitle(text: field.label)
                    switch field.style {
                    case .choice(let options, let custom):
                        choices(field, options: options, custom: custom)
                    case .multiChoice(let options):
                        multiChoices(field, options: options)
                    case .text(let prompt):
                        textField(field, prompt: prompt, multiline: false)
                    case .number(let prompt):
                        textField(field, prompt: prompt, multiline: false)
                            .keyboardType(.numberPad)
                    case .multiline(let prompt):
                        textField(field, prompt: prompt, multiline: true)
                    }
                }
            }
        }
        .card()
        .onAppear { drafts = values }
        // Valeurs posées d'ailleurs (fiche TMDB, recette importée) : le champ en cours de saisie reste.
        .onChange(of: values) { _, updated in
            for field in fields where field.key != focused { drafts[field.key] = updated[field.key] }
        }
        .onChange(of: focused) { previous, _ in
            if !immediate, let previous { commit(previous, drafts[previous]) }
        }
        .onDisappear {
            if !immediate, let focused { commit(focused, drafts[focused]) }
        }
    }

    /// Toucher la valeur choisie la retire. Une valeur venue d'ailleurs reste affichée. `custom` :
    /// « Autre… » ajoute une valeur, retenue pour la suite (appui long pour l'oublier).
    private func choices(_ field: TemplateField, options: [String], custom: Bool) -> some View {
        let current = drafts[field.key]
        let added = custom ? CustomChoices.values(for: field.key).filter { !options.contains($0) } : []
        var all = options + added
        if let current, !all.contains(current) { all.append(current) }
        return FlowLayout(spacing: 6) {
            ForEach(all, id: \.self) { option in
                ChoiceChip(label: option, selected: current == option) {
                    let value = current == option ? nil : option
                    drafts[field.key] = value
                    commit(field.key, value)
                }
                .contextMenu {
                    if added.contains(option) {
                        Button("Oublier « \(option) »", systemImage: "trash", role: .destructive) {
                            CustomChoices.remove(option, for: field.key)
                            choicesVersion += 1
                        }
                    }
                }
            }
            if custom {
                ChoiceChip(label: "Autre…", symbol: "plus", selected: false) {
                    customText = ""
                    customField = field.key
                }
                .accessibilityIdentifier("field-\(field.key)-other")
            }
        }
        .id(choicesVersion)
        .alert("Autre \(field.label.lowercased())", isPresented: Binding(
            get: { customField == field.key },
            set: { if !$0 { customField = nil } }
        )) {
            TextField("HBO, Arte…", text: $customText)
            Button("Ajouter") {
                let value = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                CustomChoices.add(value, for: field.key)
                drafts[field.key] = value
                commit(field.key, value)
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    /// Plusieurs valeurs, une par ligne dans `genres` ; `genre` garde la première pour l'affichage
    /// des versions précédentes.
    private func multiChoices(_ field: TemplateField, options: [String]) -> some View {
        let selected = TemplateField.values(field.key, in: drafts)
        let all = options + selected.filter { !options.contains($0) }
        return FlowLayout(spacing: 6) {
            ForEach(all, id: \.self) { option in
                ChoiceChip(label: option, selected: selected.contains(option)) {
                    var values = selected
                    if let index = values.firstIndex(of: option) {
                        values.remove(at: index)
                    } else {
                        values.append(option)
                    }
                    let joined = values.isEmpty ? nil : values.joined(separator: "\n")
                    drafts[field.key] = joined
                    commit(field.key, joined)
                    if field.key == "genres" {
                        drafts["genre"] = values.first
                        commit("genre", values.first)
                    }
                }
            }
        }
    }

    private func textField(_ field: TemplateField, prompt: String, multiline: Bool) -> some View {
        let binding = Binding<String>(
            get: { drafts[field.key] ?? "" },
            set: { value in
                drafts[field.key] = value
                if immediate { commit(field.key, value) }
            })
        return Group {
            if multiline {
                TextField(prompt, text: binding, axis: .vertical)
                    .lineLimit(3...12)
            } else {
                TextField(prompt, text: binding)
                    .submitLabel(.done)
                    .onSubmit { focused = nil }
            }
        }
        .font(.manrope(15, .medium, relativeTo: .body))
        .foregroundStyle(Palette.text)
        .focused($focused, equals: field.key)
        .accessibilityIdentifier("field-\(field.key)")
    }
}
