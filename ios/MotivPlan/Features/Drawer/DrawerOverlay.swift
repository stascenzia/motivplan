import SwiftUI

enum DrawerDetent: CaseIterable {
    case peek, half, full
}

/// Tiroir maison à paliers, dans la même hiérarchie que la journée (ZStack) et non en `.sheet` :
/// une sheet désactive la vue derrière elle, et un glisser doit pouvoir la traverser (ADR-008).
struct DrawerOverlay<Content: View>: View {
    @Binding var detent: DrawerDetent
    @ViewBuilder let content: Content

    @GestureState private var dragOffset: CGFloat = 0

    private static var peekHeight: CGFloat { 112 }

    var body: some View {
        GeometryReader { geometry in
            let available = geometry.size.height
            let height = max(Self.peekHeight, height(for: detent, in: available) - dragOffset)
            VStack(spacing: 0) {
                handle(available: available)
                content
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: min(height, available), alignment: .top)
            .background(.regularMaterial,
                        in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 10, y: -2)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .animation(.spring(duration: 0.32), value: detent)
        }
    }

    private func handle(available: CGFloat) -> some View {
        Capsule()
            .fill(.secondary.opacity(0.5))
            .frame(width: 38, height: 5)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                detent = detent == .peek ? .half : .peek
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in state = value.translation.height }
                    .onEnded { value in
                        let projected = height(for: detent, in: available) - value.predictedEndTranslation.height
                        detent = DrawerDetent.allCases.min {
                            abs(height(for: $0, in: available) - projected) < abs(height(for: $1, in: available) - projected)
                        } ?? detent
                    }
            )
            .accessibilityIdentifier("drawer-handle")
            .accessibilityLabel("Tiroir")
            .accessibilityAddTraits(.isButton)
    }

    private func height(for detent: DrawerDetent, in available: CGFloat) -> CGFloat {
        switch detent {
        case .peek: Self.peekHeight
        case .half: available * 0.48
        case .full: available * 0.9
        }
    }
}
