import CoreModels
import SwiftUI

/// Capture plein écran (bouton « + », widget) : juste un titre, tout part dans la boîte.
/// Le clavier reste levé pour enchaîner ; les dernières captures s'affichent au-dessus.
struct CaptureScreen: View {
    let source: TaskSource

    private struct Added: Identifiable {
        let id: UUID
        let title: String
        let at: Date
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    @State private var draft = ""
    @State private var added: [Added] = []
    @State private var captureCount = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScreenHeader(title: "Capturer", subtitle: "Juste un titre. Tout part dans la boîte de réception.") {
                RoundIconButton(label: "Fermer", systemImage: "xmark") { dismiss() }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !added.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            GroupLabel(text: "Ajoutées à l'instant")
                            ForEach(added.prefix(4)) { item in
                                addedRow(item.title, at: item.at)
                            }
                        }
                    }
                    shortcutsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .scrollDismissesKeyboard(.never)
        }
        .safeAreaInset(edge: .bottom) {
            FieldCard(highlighted: true) {
                TextField("Que dois-tu faire ?", text: $draft)
                    .font(.manrope(17, .semibold, relativeTo: .body))
                    .foregroundStyle(Palette.text)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .accessibilityIdentifier("capture-field")
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 44, height: 44)
                        .background(Palette.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ajouter")
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .screenBackground()
        .sensoryFeedback(.impact(weight: .light), trigger: captureCount)
        .alert("Action impossible", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            // Sur iOS 17, le focus au premier rendu peut demander un léger différé (plan, §Capture).
            try? await Task.sleep(for: .milliseconds(150))
            focused = true
        }
    }

    private func addedRow(_ title: String, at date: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(Palette.accentSoft)
                .frame(width: 26, height: 26)
                .background(Palette.accent.opacity(0.18), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.taskTitle)
                .foregroundStyle(Palette.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(date, format: .relative(presentation: .named))
                .font(.meta)
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aussi sans ouvrir l'app, même hors-ligne")
                .font(.chip)
                .foregroundStyle(Palette.textSoft)
            shortcut("waveform", "« Dis Siri, ajoute une tâche dans MotivPlan »")
            shortcut("square.grid.2x2", "Widget d'accueil ou d'écran verrouillé, bouton Action")
        }
        .card(Palette.surfaceLow, padding: 16)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        }
    }

    private func shortcut(_ systemImage: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 34)
                .background(Palette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(text)
                .font(.manrope(13, .medium, relativeTo: .footnote))
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func submit() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        do {
            let task = try TaskStore(context: context).capture(title, source: source)
            added.insert(Added(id: task.id, title: title, at: .now), at: 0)
            captureCount += 1
            draft = ""
            focused = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
