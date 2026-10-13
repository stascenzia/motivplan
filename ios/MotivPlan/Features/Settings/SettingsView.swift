import CoreModels
import SwiftUI
import TimelineEngine

/// Réglages : heure de départ du jour, durées par catégorie.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppSettings.load()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $settings.dayStart, in: 0...(22 * 60), step: 15) {
                        LabeledContent("Début de journée", value: TimeText.clock(settings.dayStart))
                    }
                } footer: {
                    Text("La première tâche de la journée commence à cette heure.")
                }

                Section {
                    ForEach(TaskCategory.allCases, id: \.self) { category in
                        Stepper(value: duration(category), in: Durations.minimum...480, step: 5) {
                            LabeledContent(category.label, value: TimeText.duration(duration(category).wrappedValue))
                        }
                    }
                } header: {
                    Text("Durées par défaut")
                } footer: {
                    Text("Utilisées quand tu déposes une tâche qui n'a pas encore de durée. Sans catégorie : \(TimeText.duration(Durations.fallback)).")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .onChange(of: settings) { _, value in value.save() }
        }
    }

    private func duration(_ category: TaskCategory) -> Binding<Minutes> {
        Binding(
            get: { settings.durations[category] ?? Durations.fallback },
            set: { settings.durations[category] = $0 }
        )
    }
}
