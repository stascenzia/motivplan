import SwiftUI

/// En-tête d'écran des maquettes : titre en grand, sous-titre discret, boutons à droite.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    /// Petit texte au-dessus du titre (« Lundi » au-dessus de « 12 octobre »).
    var overline: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                if let overline {
                    Text(overline)
                        .font(.subtitle)
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(title)
                    .font(.screenTitle)
                    .tracking(-0.6)
                    .foregroundStyle(Palette.text)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.subtitle)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, overline: String? = nil) {
        self.init(title: title, subtitle: subtitle, overline: overline) { EmptyView() }
    }
}

/// En-tête de groupe : petites majuscules espacées, point de couleur facultatif.
struct GroupLabel: View {
    let text: String
    var dot: Color?
    var systemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            if let dot {
                Circle().fill(dot).frame(width: 8, height: 8)
            }
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.textTertiary)
            }
            Text(text.uppercased())
                .font(.groupLabel)
                .tracking(0.7)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Puce : étiquette arrondie pour un état, une échéance, un filtre.
struct Chip: View {
    enum Tone { case neutral, accent, warning, quiet, selected }

    let text: String
    var systemImage: String?
    var dot: Color?
    var tone: Tone = .neutral
    var height: CGFloat = 24

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 7, height: 7)
            }
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.manrope(height > 28 ? 13 : 11, .bold, relativeTo: .caption))
        .foregroundStyle(foreground)
        .padding(.horizontal, height > 28 ? 12 : 8)
        .frame(minHeight: height)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .neutral: Palette.textSoft
        case .accent: Palette.accentText
        case .warning: Palette.warning
        case .quiet: Palette.textTertiary
        case .selected: Palette.onAccent
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: Palette.control
        case .accent: Palette.accentWash
        case .warning: Palette.warningWash
        case .quiet: .clear
        case .selected: Palette.text
        }
    }
}

extension View {
    /// Carte des maquettes : surface arrondie, sans ombre.
    func card(_ fill: Color = Palette.surface, radius: CGFloat = Radius.card, padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Fond de toutes les pages.
    func screenBackground() -> some View {
        background(Palette.background.ignoresSafeArea())
    }

    /// Formulaire système (réglages, éditeurs) aux couleurs des maquettes : fond de page,
    /// lignes en cartes. À poser sur le `Form`, et `formRow()` sur chacune de ses sections.
    func themedForm() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Palette.background.ignoresSafeArea())
            .font(.manrope(15, .semibold, relativeTo: .body))
            .foregroundStyle(Palette.text)
            .toolbarBackground(Palette.background, for: .navigationBar)
    }

    func formRow() -> some View {
        listRowBackground(Palette.surface)
    }
}

/// Bouton rond de 44 points (fermer, réglages, retour).
struct RoundIconButton: View {
    let label: String
    let systemImage: String
    var fill: Color = Palette.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.text)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Bouton « − » / « + » carré des réglages par pas.
struct StepButton: View {
    let text: String
    let label: String
    var width: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.manrope(text.count > 2 ? 13 : 18, .extrabold, relativeTo: .body))
                .foregroundStyle(Palette.textSoft)
                .padding(.horizontal, 10)
                .frame(minWidth: width, minHeight: 44)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Bouton en capsule : plein d'accent pour l'action principale, sinon discret.
struct PillButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .pill(prominent: prominent)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// Habillage en capsule, aussi pour l'étiquette d'un `Menu` (qui ne suit pas les styles de bouton).
    func pill(prominent: Bool = false) -> some View {
        self
            .font(.manrope(12, prominent ? .extrabold : .bold, relativeTo: .footnote))
            .foregroundStyle(prominent ? Palette.onAccent : Palette.text)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(prominent ? Palette.accent : Palette.controlHigh, in: Capsule())
    }
}

/// Champ de saisie posé sur une carte, avec un bouton d'ajout à droite.
struct FieldCard<Content: View>: View {
    var highlighted = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) { content }
            .padding(.leading, 18)
            .padding(.trailing, 6)
            .frame(minHeight: 54)
            .background(highlighted ? Color(hex: 0x1E1E24) : Palette.surface,
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(highlighted ? Palette.accent : Palette.border, lineWidth: highlighted ? 1.5 : 1)
            }
            // Halo de la capture active.
            .background {
                if highlighted {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(Palette.accent.opacity(0.12))
                        .padding(-5)
                }
            }
    }
}
