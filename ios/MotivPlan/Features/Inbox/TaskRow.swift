import CoreModels
import SwiftUI
import TimelineEngine

/// Ligne de tâche (maquette « Boîte de réception ») : icône de la source, titre, une ligne
/// discrète (source et date, échéance, jour prévu, dernière fois), point de l'étiquette.
/// Le fond est posé par le conteneur.
struct TaskRow: View {
    let task: TaskItem
    let today: DayKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sourceSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.taskTitle)
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.leading)
                details
                    .font(.meta)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let tag = task.tag {
                Circle()
                    .fill(TagColors.of(tag).vivid)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(tag.label)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    /// « Siri · il y a 12 min · Échéance demain ». L'échéance passée est en ambre.
    private var details: Text {
        var text = Text(origin).foregroundStyle(Palette.textTertiary)
        if let due = task.dueDate {
            let late = task.isOverdue(today: today)
            text = text + Text(" · Échéance \(DayLabel.text(for: due, today: today).lowercased())")
                .foregroundStyle(late ? Palette.warning : Palette.textTertiary)
        }
        if let day = task.scheduledDate {
            text = text + Text(" · Prévue \(DayLabel.text(for: day, today: today).lowercased())")
                .foregroundStyle(Palette.accentSoft)
        }
        if let last = lastDone {
            text = text + Text(" · Fait \(DayLabel.since(last, today: today))")
                .foregroundStyle(Palette.textTertiary)
        }
        return text
    }

    private var origin: String {
        let source = switch task.source {
        case .siri: "Siri"
        case .widget: "Widget"
        case .manual: "Dans l'app"
        }
        return "\(source) · \(DayLabel.since(task.createdAt, today: today))"
    }

    private var sourceSymbol: String {
        switch task.source {
        case .siri: "waveform"
        case .widget: "square.grid.2x2"
        case .manual: "pencil"
        }
    }

    /// Une permanente garde en boîte la date de la dernière fois.
    private var lastDone: Date? {
        task.status == .inbox ? task.completedAt : nil
    }
}

/// Ligne d'un élément de mémoire : avis, commentaire, date.
struct MemoryRow: View {
    let task: TaskItem
    let today: DayKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.review?.symbol ?? "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(task.review == .aime ? Palette.accent : Palette.textSecondary)
                .frame(width: 34, height: 34)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.taskTitle)
                    .foregroundStyle(Palette.text)
                if let note = task.reviewNote, !note.isEmpty {
                    Text(note)
                        .font(.manrope(13, .medium, relativeTo: .footnote))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let review = task.review { Text(review.label) }
                    if let done = task.completedAt { Text(DayLabel.since(done, today: today)) }
                }
                .font(.meta)
                .foregroundStyle(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}
