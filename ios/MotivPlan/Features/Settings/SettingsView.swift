import CoreModels
import SwiftUI
import SyncClient
import TimelineEngine

/// Réglages : heure de départ du jour, synchronisation.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncCoordinator.self) private var sync: SyncCoordinator?
    @State private var settings = AppSettings.load()
    @State private var serverText = SyncSettings.serverURL?.absoluteString ?? ""
    @State private var token = SyncSettings.token ?? ""
    @State private var invalidURL = false

    var body: some View {
        NavigationStack {
            Form {
                Group {
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

                    Section {
                        TextField("api.exemple.fr", text: $serverText)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Jeton", text: $token)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if let sync {
                            LabeledContent("État", value: statusText(sync))
                                .foregroundStyle(isFailure(sync) ? Color.gentleWarning : .secondary)
                            Button("Synchroniser maintenant", systemImage: "arrow.triangle.2.circlepath") {
                                saveSync()
                                Task { await sync.syncNow() }
                            }
                            .disabled(sync.status == .syncing)
                        }
                    } header: {
                        Text("Synchronisation")
                    } footer: {
                        Text(invalidURL
                             ? "Adresse invalide."
                             : "Facultative. Tes tâches restent sur l'iPhone et fonctionnent hors-ligne ; la synchro les copie sur ton serveur. Le jeton est rangé dans le trousseau de l'iPhone.")
                    }
                }
                .formRow()
            }
            .themedForm()
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        saveSync()
                        dismiss()
                    }
                }
            }
            .onChange(of: settings) { _, value in value.save() }
        }
    }

    private func saveSync() {
        let trimmed = serverText.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = SyncSettings.normalizedURL(trimmed)
        invalidURL = !trimmed.isEmpty && url == nil
        guard !invalidURL else { return }
        SyncSettings.serverURL = url
        SyncSettings.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        sync?.refreshConfiguration()
    }

    private func statusText(_ sync: SyncCoordinator) -> String {
        switch sync.status {
        case .notConfigured: return "Non configurée"
        case .syncing: return "En cours…"
        case .failed(let message): return message
        case .idle:
            guard let last = sync.lastSuccess else { return "Prête" }
            return "À jour, " + last.formatted(.relative(presentation: .named))
        }
    }

    private func isFailure(_ sync: SyncCoordinator) -> Bool {
        if case .failed = sync.status { return true }
        return false
    }
}
