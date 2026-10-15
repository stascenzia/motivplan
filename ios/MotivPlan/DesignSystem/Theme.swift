import CoreModels
import SwiftUI

/// Couleurs des maquettes (`docs/design-etude.md`). L'app est toujours sombre : un seul jeu de valeurs.
/// Un choix visuel se change ici, à un seul endroit.
enum Palette {
    // Fonds, du plus bas au plus haut.
    static let background = Color(hex: 0x0E0E11)
    static let surfaceLow = Color(hex: 0x141418)
    static let surface = Color(hex: 0x18181C)
    static let bar = Color(hex: 0x1B1B21)
    static let raised = Color(hex: 0x202026)
    static let field = Color(hex: 0x23232B)
    static let control = Color(hex: 0x26262D)
    static let controlHigh = Color(hex: 0x2E2E38)

    // Bordures et traits.
    static let hairline = Color(hex: 0x222228)
    static let border = Color(hex: 0x2C2C33)
    static let borderStrong = Color(hex: 0x3A3A44)
    static let ring = Color(hex: 0x4A4A55)

    // Texte.
    static let text = Color(hex: 0xF4F4F6)
    static let textSoft = Color(hex: 0xD8D8DE)
    static let textSecondary = Color(hex: 0xA3A3AD)
    static let textTertiary = Color(hex: 0x8A8A95)
    static let textMuted = Color(hex: 0x7C7C87)
    static let textFaint = Color(hex: 0x5A5A66)

    // Accent et signaux.
    static let accent = Color(hex: 0x8C8CFF)
    static let accentSoft = Color(hex: 0xB9B9FF)
    static let accentText = Color(hex: 0xC4C4FF)
    static let accentWash = Color(hex: 0x8C8CFF).opacity(0.16)
    /// Texte posé sur l'accent ou sur une couleur vive.
    static let onAccent = Color(hex: 0x0E0E11)
    /// Retard et débordement : ambre doux, jamais de rouge (principe 2).
    static let warning = Color(hex: 0xE2B062)
    static let warningWash = Color(hex: 0xE2B062).opacity(0.14)
    /// Heure fixe (ancre).
    static let anchor = Color(hex: 0xD8D8DE)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Couleur d'une tâche : celle de son étiquette (décision du 2026-10-15). Sans étiquette, gris.
struct TagColors {
    /// Points, icônes, capsule d'une tâche faite.
    let vivid: Color
    /// Fond sombre d'une capsule à venir.
    let deep: Color

    static let untagged = TagColors(vivid: Palette.textSecondary, deep: Palette.control)

    static func of(_ tag: TaskTag?) -> TagColors {
        switch tag {
        case .urgent: TagColors(vivid: Color(hex: 0xE58FB8), deep: Color(hex: 0x3A2733))
        case .travail: TagColors(vivid: Color(hex: 0xC9D16E), deep: Color(hex: 0x2E301E))
        case .medium: TagColors(vivid: Color(hex: 0x6BA8F0), deep: Color(hex: 0x1E2A3A))
        case .detente: TagColors(vivid: Color(hex: 0x5FC4B0), deep: Color(hex: 0x1F302D))
        case nil: .untagged
        }
    }
}

/// Police Manrope embarquée (licence OFL, `Resources/Fonts`), qui suit la taille de texte choisie
/// dans les réglages d'iOS (Dynamic Type) grâce à `relativeTo`.
enum Manrope: String {
    case medium = "Manrope-Medium"
    case semibold = "Manrope-SemiBold"
    case bold = "Manrope-Bold"
    case extrabold = "Manrope-ExtraBold"
}

extension Font {
    static func manrope(_ size: CGFloat, _ weight: Manrope, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }

    /// « Boîte de réception », « 12 octobre ».
    static let screenTitle = manrope(30, .extrabold, relativeTo: .largeTitle)
    /// « Tiroir », « Octobre 2026 ».
    static let blockTitle = manrope(18, .extrabold, relativeTo: .title3)
    /// Titre d'une tâche.
    static let taskTitle = manrope(15, .semibold, relativeTo: .body)
    /// Texte courant fort (boutons, lignes de réglages).
    static let rowTitle = manrope(15, .bold, relativeTo: .body)
    /// Sous-titre d'écran.
    static let subtitle = manrope(14, .semibold, relativeTo: .subheadline)
    /// Puces et boutons secondaires.
    static let chip = manrope(13, .bold, relativeTo: .footnote)
    /// Heures, durées, métadonnées.
    static let meta = manrope(12, .semibold, relativeTo: .caption)
    /// En-tête de groupe, en majuscules.
    static let groupLabel = manrope(12, .extrabold, relativeTo: .caption)
    /// Libellés de la barre d'onglets.
    static let tabLabel = manrope(11, .bold, relativeTo: .caption2)
}

/// Rayons des formes : cartes, lignes, puces.
enum Radius {
    static let card: CGFloat = 22
    static let row: CGFloat = 18
    static let large: CGFloat = 26
}
