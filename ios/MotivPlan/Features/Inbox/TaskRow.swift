import CoreModels
import SwiftUI
import TimelineEngine

/// Ligne de tâche : titre, puis étiquette, échéance et dernière fois, en discret.
struct TaskRow: View {
    let task: TaskItem
    let today: DayKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(task.title)
                    .foregroundStyle(.primary)
                if task.source == .siri {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel("Capturée avec Siri")
                }
            }
            if hasDetails {
                HStack(spacing: 8) {
                    if let tag = task.tag {
                        Label(tag.label, systemImage: tag.symbol)
                            .foregroundStyle(tag.tint)
                    }
                    if let due = task.dueDate {
                        Label(DayLabel.text(for: due, today: today), systemImage: "flag")
                            .foregroundStyle(task.isOverdue(today: today) ? Color.gentleWarning : .secondary)
                    }
                    if let day = task.scheduledDate {
                        Label(DayLabel.text(for: day, today: today), systemImage: "calendar")
                    }
                    if let last = lastDone {
                        Label("Fait \(DayLabel.since(last, today: today))", systemImage: "checkmark")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 2)
    }

    /// Une permanente garde en boîte la date de la dernière fois.
    private var lastDone: Date? {
        task.status == .inbox ? task.completedAt : nil
    }

    private var hasDetails: Bool {
        task.tag != nil || task.dueDate != nil || task.scheduledDate != nil || lastDone != nil
    }
}

/// Ligne d'un élément de mémoire : avis, date, commentaire.
struct MemoryRow: View {
    let task: TaskItem
    let today: DayKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: task.review?.symbol ?? "checkmark.circle")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                if let note = task.reviewNote {
                    Text(note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let review = task.review { Text(review.label) }
                    if let done = task.completedAt { Text(DayLabel.since(done, today: today)) }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
