import CoreModels
import SwiftUI
import UIKit

/// Couleurs de l'app, en clair (par défaut depuis les retours du 2026-11-03 : « moins tout sombre,
/// plus coloré ») et en sombre (les maquettes, `docs/design-etude.md`). Chaque jeton porte ses deux
/// valeurs ; l'apparence se choisit dans les réglages. Un choix visuel se change ici, à un seul endroit.
enum Palette {
    // Fonds, du plus bas au plus haut.
    static let background = Color(light: 0xF4F2FB, dark: 0x0E0E11)
    static let surfaceLow = Color(light: 0xEDEAF8, dark: 0x141418)
    static let surface = Color(light: 0xFFFFFF, dark: 0x18181C)
    static let bar = Color(light: 0xFFFFFF, dark: 0x1B1B21)
    static let raised = Color(light: 0xF1EEFA, dark: 0x202026)
    static let field = Color(light: 0xEDEAF7, dark: 0x23232B)
    static let control = Color(light: 0xECE9F6, dark: 0x26262D)
    static let controlHigh = Color(light: 0xE3DFF2, dark: 0x2E2E38)
    /// Puce de choix retenue.
    static let selectedFill = Color(light: 0xE6E3FF, dark: 0x2A2A33)
    /// Carte du jour en cours, champ de capture actif.
    static let highlightFill = Color(light: 0xF7F6FF, dark: 0x1C1C24)

    // Bordures et traits.
    static let hairline = Color(light: 0xE8E4F3, dark: 0x222228)
    static let border = Color(light: 0xDCD7EC, dark: 0x2C2C33)
    static let borderStrong = Color(light: 0xC9C3DF, dark: 0x3A3A44)
    static let ring = Color(light: 0xB4AECB, dark: 0x4A4A55)

    // Texte.
    static let text = Color(light: 0x1B1931, dark: 0xF4F4F6)
    static let textSoft = Color(light: 0x2F2C47, dark: 0xD8D8DE)
    static let textSecondary = Color(light: 0x5D5977, dark: 0xA3A3AD)
    static let textTertiary = Color(light: 0x777391, dark: 0x8A8A95)
    static let textMuted = Color(light: 0x8C88A5, dark: 0x7C7C87)
    static let textFaint = Color(light: 0xB2AEC6, dark: 0x5A5A66)

    // Accent et signaux.
    static let accent = Color(light: 0x5B5BF0, dark: 0x8C8CFF)
    static let accentSoft = Color(light: 0x4C4CD9, dark: 0xB9B9FF)
    static let accentText = Color(light: 0x4141C2, dark: 0xC4C4FF)
    static let accentWash = Color(light: 0x5B5BF0, dark: 0x8C8CFF).opacity(0.14)
    /// Second accent, pour les dégradés et les célébrations.
    static let accentAlt = Color(light: 0xE0558F, dark: 0xE58FB8)
    /// Texte posé sur l'accent ou sur une couleur vive.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0E0E11)
    /// Retard et débordement : ambre doux, jamais de rouge (principe 2).
    static let warning = Color(light: 0xB97A12, dark: 0xE2B062)
    static let warningWash = Color(light: 0xD99A2B, dark: 0xE2B062).opacity(0.16)
    /// Heure fixe (ancre).
    static let anchor = Color(light: 0x3A3656, dark: 0xD8D8DE)
    /// Barre de charge d'un jour qui n'est pas aujourd'hui.
    static let loadBar = Color(light: 0xA9A4E8, dark: 0x5C5C7A)
    /// Pastille de compte de la barre d'onglets.
    static let badge = Color(light: 0xE3DFF2, dark: 0x34344A)
    /// Ombre des éléments flottants (barre d'onglets, tiroir, tâche soulevée).
    static let shadow = Color(light: 0x2A2160, dark: 0x000000).opacity(0.18)
    static let shadowStrong = Color(light: 0x2A2160, dark: 0x000000).opacity(0.28)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Couleur qui suit l'apparence (claire ou sombre) de l'écran.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor.dynamic(light: light, dark: dark))
    }
}

extension UIColor {
    /// Hors de l'acteur principal : UIKit résout une couleur dynamique sur n'importe quel fil ; une
    /// fermeture créée sur l'acteur principal y serait rattachée et planterait ailleurs.
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> UIColor {
        UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    nonisolated convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// Apparence choisie dans les réglages. Claire par défaut.
enum AppAppearance: String, CaseIterable, Identifiable {
    case light, dark, system

    static let storageKey = "settings.appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Claire"
        case .dark: "Sombre"
        case .system: "Comme l'iPhone"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

/// Couleur d'une tâche : celle de son étiquette (décision du 2026-10-15). Sans étiquette, gris.
struct TagColors {
    /// Points, icônes, capsule d'une tâche faite.
    let vivid: Color
    /// Fond d'une capsule à venir : teinte sombre en sombre, pâle en clair.
    let deep: Color

    static let untagged = TagColors(vivid: Palette.textSecondary, deep: Palette.control)

    static func of(_ tag: TaskTag?) -> TagColors {
        switch tag {
        case .urgent: TagColors(vivid: Color(light: 0xE0558F, dark: 0xE58FB8), deep: Color(light: 0xFCE4EF, dark: 0x3A2733))
        case .travail: TagColors(vivid: Color(light: 0x8A9A12, dark: 0xC9D16E), deep: Color(light: 0xF0F4D2, dark: 0x2E301E))
        case .medium: TagColors(vivid: Color(light: 0x2F7FE0, dark: 0x6BA8F0), deep: Color(light: 0xE0ECFC, dark: 0x1E2A3A))
        case .detente: TagColors(vivid: Color(light: 0x1FA38A, dark: 0x5FC4B0), deep: Color(light: 0xDBF3EE, dark: 0x1F302D))
        case nil: .untagged
        }
    }
}

/// Couleur d'une section, choisie par sa place dans la liste : les tuiles ne sont plus toutes grises.
/// Pas de rouge ni d'ambre, réservés aux signaux (principe 2).
enum SectionColors {
    private static let hues: [TagColors] = [
        TagColors(vivid: Color(light: 0x5B5BF0, dark: 0x8C8CFF), deep: Color(light: 0xE6E5FF, dark: 0x25254A)),
        TagColors(vivid: Color(light: 0x1FA38A, dark: 0x5FC4B0), deep: Color(light: 0xDBF3EE, dark: 0x1F302D)),
        TagColors(vivid: Color(light: 0xE07A2E, dark: 0xF2A167), deep: Color(light: 0xFDEBDD, dark: 0x3A2A1F)),
        TagColors(vivid: Color(light: 0x2F7FE0, dark: 0x6BA8F0), deep: Color(light: 0xE0ECFC, dark: 0x1E2A3A)),
        TagColors(vivid: Color(light: 0xE0558F, dark: 0xE58FB8), deep: Color(light: 0xFCE4EF, dark: 0x3A2733)),
        TagColors(vivid: Color(light: 0x8F55E0, dark: 0xB58CF0), deep: Color(light: 0xEFE4FC, dark: 0x2E2440)),
        TagColors(vivid: Color(light: 0x7F9A1A, dark: 0xB7C95F), deep: Color(light: 0xEEF4D6, dark: 0x2C301E)),
    ]

    static func at(_ index: Int) -> TagColors {
        hues[((index % hues.count) + hues.count) % hues.count]
    }

    /// Couleur stable pour un élément (une période dans le calendrier).
    static func of(_ id: UUID) -> TagColors {
        at(Int(id.uuid.0) + Int(id.uuid.1))
    }

    /// « À trier » garde la couleur de l'app.
    static let inbox = TagColors(vivid: Palette.accent, deep: Palette.accentWash)
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
