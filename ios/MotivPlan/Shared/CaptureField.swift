import SwiftUI

/// Champ de capture permanent (boîte de réception, tiroir, sections).
/// Entrée = création ; le champ se vide et garde le clavier pour enchaîner.
struct CaptureField: View {
    var focus: FocusState<Bool>.Binding
    var placeholder = "Une idée, une tâche…"
    var identifier = "inbox-capture-field"
    /// Fond du champ : plus clair dans le tiroir, qui est déjà une surface.
    var fill: Color = Palette.surface
    let onSubmit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $draft)
                .font(.manrope(15, .semibold, relativeTo: .body))
                .foregroundStyle(Palette.text)
                .focused(focus)
                .submitLabel(.done)
                .onSubmit(submit)
                .accessibilityIdentifier(identifier)
            Button(action: submit) {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 40, height: 40)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajouter")
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 52)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(focus.wrappedValue ? Palette.accent : Palette.border, lineWidth: 1)
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
