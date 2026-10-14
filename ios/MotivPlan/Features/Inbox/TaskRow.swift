import CoreModels
import SwiftUI
import TimelineEngine

/// Ligne de tâche : titre, puis catégorie, échéance et importance en discret.
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
                    if let category = task.category {
                        Label(category.label, systemImage: "tag")
                    }
                    if let due = task.dueDate {
                        Label(DayLabel.text(for: due, today: today), systemImage: "flag")
                            .foregroundStyle(task.isOverdue(today: today) ? Color.gentleWarning : .secondary)
                    }
                    if task.importance == .haute {
                        Label("Importante", systemImage: "exclamationmark")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            }
        }
        .padding(.vertical, 2)
    }

    private var hasDetails: Bool {
        task.category != nil || task.dueDate != nil || task.importance == .haute
    }
}
