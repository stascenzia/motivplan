import SwiftUI

/// Tuile de section (boîte de réception, mémoire) : icône sur sa couleur, nombre, nom.
struct SectionTile: View {
    let name: String
    let symbol: String
    let count: Int
    let colors: TagColors
    let selected: Bool
    /// Survolée par une tâche qu'on glisse.
    var targeted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(selected ? Palette.onAccent : colors.vivid)
                        .frame(width: 28, height: 28)
                        .background(selected ? colors.vivid : colors.deep,
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Spacer(minLength: 2)
                    Text("\(count)")
                        .font(.manrope(20, .extrabold, relativeTo: .title3).monospacedDigit())
                        .foregroundStyle(count > 0 ? Palette.text : Palette.textFaint)
                }
                Spacer(minLength: 6)
                Text(name)
                    .font(.manrope(12, .bold, relativeTo: .caption))
                    .foregroundStyle(Palette.textSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(selected ? colors.deep : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(selected || targeted ? colors.vivid : Palette.hairline,
                                  lineWidth: targeted ? 2.5 : selected ? 1.5 : 1)
            }
            .scaleEffect(targeted ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(count)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Tuile « Nouvelle section » / « Nouvelle liste » : contour pointillé.
struct NewSectionTile: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                Text(title)
                    .font(.manrope(12, .bold, relativeTo: .caption))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 84)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Palette.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .buttonStyle(.plain)
    }
}
