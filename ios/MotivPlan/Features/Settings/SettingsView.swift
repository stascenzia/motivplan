import CoreModels
import SwiftUI
import TimelineEngine

/// Réglages : heure de départ du jour.
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
                    Text("Les durées suggérées se règlent dans chaque section, depuis la boîte de réception.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
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
}
