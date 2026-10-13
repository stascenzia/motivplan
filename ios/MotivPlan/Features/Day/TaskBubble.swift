import CoreModels
import SwiftUI
import TimelineEngine

/// Bulle d'une tâche dans la journée. Hauteur proportionnelle à la durée.
struct TaskBubble: View {
    static let pointsPerMinute: CGFloat = 1.4
    static let minimumHeight: CGFloat = 46

    let task: TaskItem
    let placement: Placement
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isDone ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isDone ? "Marquer comme non faite" : "Marquer comme faite")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(height > 70 ? 3 : 1)
                HStack(spacing: 8) {
                    Text(TimeText.duration(placement.end - placement.start))
                    if placement.isAnchored {
                        Label("Heure fixe", systemImage: "pin.fill")
                    }
                    if placement.pushedPastAnchor != nil {
                        Label("Décalée", systemImage: "arrow.turn.right.down")
                    }
                    if placement.overlapsAnchor {
                        Label("Chevauche", systemImage: "square.on.square")
                            .foregroundStyle(Color.gentleWarning)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
        .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            if placement.isAnchored {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1.5)
            }
        }
        .opacity(task.isDone ? 0.65 : 1)
        .animation(.spring(duration: 0.35), value: task.isDone)
    }

    var height: CGFloat {
        max(Self.minimumHeight, CGFloat(placement.end - placement.start) * Self.pointsPerMinute)
    }

    private var fill: Color {
        switch task.category {
        case .quotidienne: .mint.opacity(0.18)
        case .courte: .teal.opacity(0.18)
        case .moyenne: .blue.opacity(0.16)
        case .longue: .indigo.opacity(0.18)
        case .pro: .purple.opacity(0.16)
        case nil: .gray.opacity(0.14)
        }
    }
}

/// Trou entre deux tâches (une ancre plus tard dans la journée).
struct GapView: View {
    let minutes: Minutes

    var body: some View {
        if minutes >= 15 {
            HStack(spacing: 6) {
                Rectangle().fill(.quaternary).frame(width: 2)
                Text("Libre · \(TimeText.duration(minutes))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.leading, 70)
            .frame(maxWidth: .infinity, minHeight: min(CGFloat(minutes) * TaskBubble.pointsPerMinute, 40),
                   alignment: .leading)
        } else {
            Color.clear.frame(height: CGFloat(minutes) * TaskBubble.pointsPerMinute)
        }
    }
}
