import SwiftUI

/// Journal du spike Siri du lot 0 (ADR-003) : ce que Siri a capturé, en attendant
/// l'AddTaskIntent définitif du lot 4. Accessible depuis la boîte de réception.
struct SpikeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [String] = []

    var body: some View {
        List {
            if entries.isEmpty {
                Text("Aucune capture Siri pour l'instant.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries.reversed(), id: \.self) { Text($0) }
        }
        .navigationTitle("Spike Siri")
        .toolbar {
            Button("Vider", role: .destructive) {
                SpikeLog.clear()
                reload()
            }
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
    }

    private func reload() {
        entries = SpikeLog.all()
    }
}
