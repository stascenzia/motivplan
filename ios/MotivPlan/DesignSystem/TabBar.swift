import Observation
import SwiftUI

enum AppTab: Hashable {
    case planning, inbox, calendar
}

/// Barre d'onglets des maquettes, dessinée à la main : flottante, arrondie, avec le bouton
/// de capture au centre (décision du 2026-10-15). Progrès arrivera en v2.
enum TabBarMetrics {
    static let height: CGFloat = 68
    static let bottomGap: CGFloat = 8
    /// Place à laisser sous le contenu défilant pour qu'il ne passe pas sous la barre.
    static let contentInset: CGFloat = height + bottomGap + 16
}

/// Visibilité de la barre : un écran poussé (détail, section) ou le tiroir ouvert la masquent.
@MainActor
@Observable
final class AppChrome {
    private var hiders: Set<UUID> = []

    var isTabBarHidden: Bool { !hiders.isEmpty }

    func setHidden(_ hidden: Bool, by id: UUID) {
        if hidden { hiders.insert(id) } else { hiders.remove(id) }
    }
}

private struct HidesTabBar: ViewModifier {
    let hidden: Bool
    @Environment(AppChrome.self) private var chrome: AppChrome?
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { chrome?.setHidden(hidden, by: id) }
            .onChange(of: hidden) { _, value in chrome?.setHidden(value, by: id) }
            .onDisappear { chrome?.setHidden(false, by: id) }
    }
}

extension View {
    /// Masque la barre d'onglets tant que cette vue est affichée (et que `hidden` est vrai).
    func hidesTabBar(_ hidden: Bool = true) -> some View {
        modifier(HidesTabBar(hidden: hidden))
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    let inboxBadge: Int
    let onCapture: () -> Void

    var body: some View {
        HStack {
            item(.planning, title: "Planning", systemImage: "list.bullet")
            Spacer(minLength: 0)
            item(.inbox, title: "Boîte", systemImage: "tray", badge: inboxBadge)
            Spacer(minLength: 0)
            Button(action: onCapture) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
                    .frame(width: 54, height: 54)
                    .background(Palette.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Capturer une tâche")
            .accessibilityIdentifier("tab-capture")
            Spacer(minLength: 0)
            item(.calendar, title: "Calendrier", systemImage: "calendar")
        }
        .padding(.horizontal, 18)
        .frame(height: TabBarMetrics.height)
        .background(Palette.bar, in: Capsule())
        .overlay { Capsule().strokeBorder(Palette.border, lineWidth: 1) }
        .shadow(color: .black.opacity(0.55), radius: 20, y: 16)
        .padding(.horizontal, 16)
        .padding(.bottom, TabBarMetrics.bottomGap)
    }

    private func item(_ tab: AppTab, title: String, systemImage: String, badge: Int = 0) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Palette.accent : Palette.textTertiary)
                Text(title)
                    .font(.manrope(11, selected ? .extrabold : .semibold, relativeTo: .caption2))
                    .foregroundStyle(selected ? Palette.text : Palette.textTertiary)
            }
            .frame(width: 70, height: 56)
            .overlay(alignment: .topTrailing) {
                if badge > 0 {
                    Text("\(badge)")
                        .font(.manrope(10, .extrabold, relativeTo: .caption2))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color(hex: 0x34344A), in: Capsule())
                        .offset(x: -8, y: 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(badge > 0 ? "\(badge) à trier" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("tab-\(title)")
    }
}
