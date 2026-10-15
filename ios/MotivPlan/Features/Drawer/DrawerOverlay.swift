import CoreModels
import SwiftData
import SwiftUI
import TimelineEngine

enum DrawerDetent: CaseIterable {
    case peek, half, full
}

/// Tiroir maison à paliers, dans la même hiérarchie que la journée (ZStack) et non en `.sheet` :
/// une sheet désactive la vue derrière elle, et un glisser doit pouvoir la traverser (ADR-008).
///
/// Replié, c'est une carte posée au-dessus de la barre d'onglets (maquette « vue Jour ») ;
/// ouvert, une feuille qui monte du bas, la barre d'onglets masquée (maquette « tiroir ouvert »).
struct DrawerOverlay<Peek: View, Content: View>: View {
    @Binding var detent: DrawerDetent
    @ViewBuilder let peek: Peek
    @ViewBuilder let content: Content

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            let available = geometry.size.height
            Group {
                if detent == .peek {
                    peekCard(available: available)
                } else {
                    sheet(available: available)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(duration: 0.32), value: detent)
        }
    }

    private func peekCard(available: CGFloat) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
                .frame(width: 36, height: 36)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            peek
                .frame(maxWidth: .infinity, alignment: .leading)
            Capsule()
                .fill(Palette.borderStrong)
                .frame(width: 36, height: 5)
        }
        .padding(.horizontal, 16)
        .frame(height: 60)
        .background(Palette.bar, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.border, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .offset(y: min(0, dragOffset) / 3)
        .contentShape(Rectangle())
        .onTapGesture { detent = .half }
        .gesture(resizeGesture(available: available))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("drawer-handle")
        .accessibilityLabel("Tiroir")
        .accessibilityHint("Ouvre le tiroir")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { detent = .half }
        .transition(.opacity)
    }

    private func sheet(available: CGFloat) -> some View {
        let height = min(available, max(160, height(for: detent, in: available) - dragOffset))
        return VStack(spacing: 0) {
            Capsule()
                .fill(Palette.borderStrong)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { detent = .peek }
                .gesture(resizeGesture(available: available))
                .accessibilityIdentifier("drawer-handle")
                .accessibilityLabel("Tiroir")
                .accessibilityHint("Referme le tiroir")
                .accessibilityAddTraits(.isButton)
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(Palette.surface, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30,
                                                                  style: .continuous))
        .shadow(color: .black.opacity(0.5), radius: 20, y: -12)
        .ignoresSafeArea(edges: .bottom)
        .transition(.move(edge: .bottom))
    }

    private func resizeGesture(available: CGFloat) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                let projected = height(for: detent, in: available) - value.predictedEndTranslation.height
                detent = DrawerDetent.allCases.min {
                    abs(height(for: $0, in: available) - projected) < abs(height(for: $1, in: available) - projected)
                } ?? detent
            }
    }

    private func height(for detent: DrawerDetent, in available: CGFloat) -> CGFloat {
        switch detent {
        case .peek: 72
        case .half: available * 0.6
        case .full: available * 0.92
        }
    }
}

/// Texte de la carte repliée : « Tiroir · 18 tâches · 2 pour aujourd'hui ».
struct DrawerPeek: View {
    let day: DayKey
    let today: DayKey

    @Query(TaskItem.inboxDescriptor) private var tasks: [TaskItem]
    @Query(TaskSection.orderedDescriptor) private var sections: [TaskSection]

    var body: some View {
        let plannable = Set(sections.filter(\.isPlannable).map(\.id))
        let available = tasks.filter { $0.sectionId.map { plannable.contains($0) } ?? true }
        let dueToday = available.filter { $0.dueDate.map { $0 <= today } ?? false }.count
        VStack(alignment: .leading, spacing: 1) {
            Text("Tiroir")
                .font(.rowTitle)
                .foregroundStyle(Palette.text)
            Text(subtitle(count: available.count, dueToday: dueToday))
                .font(.meta)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private func subtitle(count: Int, dueToday: Int) -> String {
        guard count > 0 else { return "Vide · capture une idée avec +" }
        var text = count == 1 ? "1 tâche" : "\(count) tâches"
        if dueToday > 0 { text += " · \(dueToday) pour aujourd'hui" }
        return text
    }
}
