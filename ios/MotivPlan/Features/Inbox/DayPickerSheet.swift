import CoreModels
import SwiftUI
import TimelineEngine

/// Choix d'un jour, pour « Planifier le… » et « Échéance : choisir ».
struct DayPickerSheet: View {
    let title: String
    let initial: DayKey
    let onPick: (DayKey) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            DatePicker(title, selection: $date, in: Date.now.addingTimeInterval(-86_400 * 365)...,
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
                .screenBackground()
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Valider") {
                            onPick(DayKeys.key(for: date))
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear { date = DayKeys.date(from: initial) ?? .now }
    }
}
