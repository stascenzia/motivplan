import CoreModels
import SwiftUI
import TimelineEngine

/// Création ou modification d'une section et de ses règles (ADR-014).
struct SectionEditor: View {
    /// `nil` : nouvelle section.
    let section: TaskSection?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "folder"
    @State private var isPlannable = true
    @State private var keepsMemory = false
    @State private var repeatRule: SectionRepeat = .none
    @State private var hasDuration = false
    @State private var duration: Minutes = 30
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    private static let symbols = [
        "folder", "checkmark.circle", "sunrise", "arrow.trianglehead.2.clockwise", "cart", "fork.knife",
        "film", "tv", "book", "music.note", "gamecontroller", "figure.run",
        "house", "briefcase", "gift", "airplane", "heart", "lightbulb",
    ]

    private var store: TaskStore { TaskStore(context: context) }

    var body: some View {
        NavigationStack {
            Form {
                Group {
                    Section {
                        TextField("Nom de la section", text: $name)
                            .font(.headline)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(Self.symbols, id: \.self) { candidate in
                                Button {
                                    symbol = candidate
                                } label: {
                                    Image(systemName: candidate)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(symbol == candidate ? Color.accentColor.opacity(0.2) : Color.clear,
                                                    in: Circle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(candidate)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Section {
                        Toggle("Planifiable", isOn: $isPlannable)
                        if isPlannable {
                            Picker("Répétition", selection: $repeatRule) {
                                ForEach(SectionRepeat.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        }
                        Toggle("Garder en mémoire", isOn: $keepsMemory)
                    } header: {
                        Text("Règles")
                    } footer: {
                        Text(rulesExplanation)
                    }

                    if isPlannable {
                        Section {
                            Toggle("Durée suggérée", isOn: $hasDuration)
                            if hasDuration {
                                Stepper(value: $duration, in: Durations.minimum...480, step: 5) {
                                    LabeledContent("Durée", value: TimeText.duration(duration))
                                }
                            }
                        } footer: {
                            Text("Utilisée quand tu déposes une tâche de cette section qui n'a pas de durée. Sinon : \(TimeText.duration(Durations.fallback)).")
                        }
                    }

                    if section != nil {
                        Section {
                            Button("Supprimer la section", role: .destructive) { confirmDelete = true }
                        } footer: {
                            Text("Ses tâches retournent dans « À trier ». Rien n'est perdu.")
                        }
                    }
                }
                .formRow()
            }
            .themedForm()
            .navigationTitle(section == nil ? "Nouvelle section" : "Section")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Supprimer « \(name) » ?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let section, run({ try store.deleteSection(section) }) { dismiss() }
                }
            }
            .alert("Action impossible", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .onAppear(perform: load)
    }

    private var rulesExplanation: String {
        var lines = [isPlannable
            ? "Ses tâches apparaissent dans le tiroir et se posent dans la journée."
            : "Ses tâches ne se posent pas dans la journée (une série se regarde au fil des jours)."]
        if isPlannable { lines.append(repeatRule.explanation) }
        if keepsMemory { lines.append("Terminées, elles restent consultables avec ton avis.") }
        return lines.joined(separator: " ")
    }

    private func load() {
        guard let section else { return }
        name = section.name
        symbol = section.symbol
        isPlannable = section.isPlannable
        keepsMemory = section.keepsMemory
        repeatRule = section.repeatRule
        hasDuration = section.defaultDuration != nil
        duration = section.defaultDuration ?? Durations.fallback
    }

    private func save() {
        let rule = isPlannable ? repeatRule : .none
        let minutes = isPlannable && hasDuration ? duration : nil
        let saved = run {
            if let section {
                try store.updateSection(section, name: name, symbol: symbol, defaultDuration: minutes,
                                        isPlannable: isPlannable, keepsMemory: keepsMemory, repeatRule: rule)
            } else {
                try store.createSection(name: name, symbol: symbol, defaultDuration: minutes,
                                        isPlannable: isPlannable, keepsMemory: keepsMemory, repeatRule: rule)
            }
        }
        if saved { dismiss() }
    }

    @discardableResult
    private func run(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
