import SwiftUI

/// Écran provisoire du lot 0 : affiche ce que Siri a capturé, et le champ ouvert par le widget.
struct SpikeView: View {
    @Binding var captureRequested: Bool
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [String] = []
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Nouvelle tâche", text: $draft)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit(addDraft)
                }
                Section("Captures (spike Siri)") {
                    if entries.isEmpty {
                        Text("Aucune capture pour l'instant.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(entries.reversed(), id: \.self) { Text($0) }
                }
            }
            .navigationTitle("MotivPlan")
            .toolbar {
                Button("Vider", role: .destructive) {
                    SpikeLog.clear()
                    reload()
                }
            }
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
        .onChange(of: captureRequested) { _, requested in
            guard requested else { return }
            // Sur iOS 17, le focus au premier rendu peut demander un léger différé (plan, §Capture).
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                fieldFocused = true
                captureRequested = false
            }
        }
    }

    private func addDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        SpikeLog.append(trimmed)
        draft = ""
        reload()
    }

    private func reload() {
        entries = SpikeLog.all()
    }
}
