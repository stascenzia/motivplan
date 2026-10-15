import CoreModels
import SwiftUI
import TimelineEngine

/// Une tâche dans la frise (maquette « Planning — vue Jour ») : capsule verticale dont la hauteur
/// suit la durée, horaires et titre à côté, rond à cocher à droite. La colonne des heures est
/// dessinée par la frise.
struct TaskBubble: View {
    /// Capsule : 48 points pour un quart d'heure, puis environ un demi-point par minute.
    static func capsuleHeight(_ minutes: Minutes) -> CGFloat {
        min(max(48, 40 + CGFloat(minutes) * 0.55), 220)
    }

    static let capsuleWidth: CGFloat = 44

    let task: TaskItem
    let placement: Placement
    /// Minute actuelle si la frise montre aujourd'hui : sert à repérer la tâche en cours.
    var now: Minutes?
    let onToggle: () -> Void

    private enum Look { case done, current, anchored, upcoming }

    var body: some View {
        let colors = TagColors.of(task.tag)
        HStack(alignment: .top, spacing: 10) {
            capsule(colors)
            VStack(alignment: .leading, spacing: look == .current ? 4 : 2) {
                meta
                Text(task.title)
                    .font(look == .current ? .manrope(16, .bold, relativeTo: .body) : .taskTitle)
                    .strikethrough(look == .done)
                    .foregroundStyle(look == .done ? Palette.textMuted : Palette.text)
                    .lineLimit(height > 80 ? 3 : 2)
                if look == .current, let now {
                    Text("En cours · reste \(TimeText.duration(max(placement.end - now, 1)))")
                        .font(.manrope(12, .bold, relativeTo: .caption))
                        .foregroundStyle(colors.vivid)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 24)
                        .background(Palette.field, in: Capsule())
                }
            }
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            checkButton(colors)
        }
        .frame(minHeight: height, alignment: .top)
        .animation(.spring(duration: 0.35), value: task.isDone)
    }

    var height: CGFloat { Self.capsuleHeight(placement.end - placement.start) }

    private var look: Look {
        if task.isDone { return .done }
        if let now, placement.start <= now, now < placement.end { return .current }
        return placement.isAnchored ? .anchored : .upcoming
    }

    private var meta: some View {
        HStack(spacing: 6) {
            Text(timeRange)
                .font(.meta.monospacedDigit())
                .foregroundStyle(look == .done ? Palette.textMuted : Palette.textSecondary)
            if placement.pushedPastAnchor != nil {
                Text("· décalée")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
            if placement.overlapsAnchor {
                Text("· chevauche")
                    .font(.meta)
                    .foregroundStyle(Palette.warning)
            }
        }
        .lineLimit(1)
    }

    /// « 09:15 – 10:15 · 1 h », ou « · heure fixe » pour une ancre.
    private var timeRange: String {
        let range = "\(TimeText.clock(placement.start)) – \(TimeText.clock(placement.end))"
        return placement.isAnchored
            ? "\(range) · heure fixe"
            : "\(range) · \(TimeText.duration(placement.end - placement.start))"
    }

    private var symbol: String {
        if placement.isAnchored { return "clock" }
        return task.tag?.symbol ?? "circle.dotted"
    }

    private func capsule(_ colors: TagColors) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.capsuleWidth / 2, style: .continuous)
        let (fill, stroke, lineWidth, iconColor): (Color, Color, CGFloat, Color) = switch look {
        case .done: (colors.vivid, .clear, 0, Palette.onAccent)
        case .current: (colors.deep, colors.vivid, 2, colors.vivid)
        case .anchored: (Palette.control, Palette.anchor, 2, Palette.text)
        case .upcoming: (colors.deep, colors.vivid, 1.5, colors.vivid)
        }
        return Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(iconColor)
            .padding(.top, look == .current ? 12 : 0)
            .frame(width: Self.capsuleWidth, height: height, alignment: look == .current ? .top : .center)
            .background(fill, in: shape)
            .overlay { shape.strokeBorder(stroke, lineWidth: lineWidth) }
            .background {
                // Halo de la tâche en cours.
                if look == .current {
                    shape.fill(colors.vivid.opacity(0.14)).padding(-5)
                }
            }
            .accessibilityHidden(true)
    }

    private func checkButton(_ colors: TagColors) -> some View {
        Button(action: onToggle) {
            ZStack {
                if look == .done {
                    Circle().fill(colors.vivid)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(Palette.onAccent)
                } else {
                    Circle().strokeBorder(look == .current ? colors.vivid : Palette.ring, lineWidth: 2)
                }
            }
            .frame(width: 26, height: 26)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isDone ? "Marquer comme non faite" : "Marquer comme faite")
    }
}

/// Trou entre deux tâches (une ancre plus tard dans la journée) : « Créneau libre · 1 h 45 ».
struct GapView: View {
    let minutes: Minutes

    var body: some View {
        if minutes >= 15 {
            HStack(spacing: 10) {
                Color.clear.frame(width: 44 + 10 + TaskBubble.capsuleWidth)
                Text("Créneau libre · \(TimeText.duration(minutes))")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .overlay {
                        Capsule().strokeBorder(Palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40)
        } else {
            Color.clear.frame(height: CGFloat(minutes) * 0.6)
        }
    }
}

/// Ligne « maintenant » : l'heure en accent, un point sur l'axe, un trait jusqu'au bord.
struct NowLine: View {
    let minutes: Minutes

    var body: some View {
        HStack(spacing: 0) {
            Text(TimeText.clock(minutes))
                .font(.manrope(11, .extrabold, relativeTo: .caption2).monospacedDigit())
                .foregroundStyle(Palette.accent)
                .frame(width: 44, alignment: .trailing)
            Circle()
                .fill(Palette.accent)
                .frame(width: 10, height: 10)
                .padding(.leading, 10 + TaskBubble.capsuleWidth / 2 - 5)
            Rectangle()
                .fill(Palette.accent)
                .frame(height: 2)
        }
        .frame(height: 14)
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Maintenant, \(TimeText.clock(minutes))")
    }
}
