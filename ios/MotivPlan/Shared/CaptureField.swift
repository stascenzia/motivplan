import SwiftUI

/// Champ de capture permanent (boîte de réception, puis tiroir au lot 3).
/// Entrée = création ; le champ se vide et garde le clavier pour enchaîner.
struct CaptureField: View {
    var focus: FocusState<Bool>.Binding
    let onSubmit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            TextField("Une pensée, une tâche…", text: $draft)
                .focused(focus)
                .submitLabel(.done)
                .onSubmit(submit)
                .accessibilityIdentifier("capture-field")
        }
    }

    private func submit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        onSubmit(title)
        draft = ""
        focus.wrappedValue = true
    }
}
