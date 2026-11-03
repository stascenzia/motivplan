import SwiftUI

/// Petites récompenses visuelles (retours du 2026-11-03 : l'app doit donner envie) : une gerbe
/// de points quand on coche, des confettis quand la journée est bouclée. Jamais de reproche.

/// Gerbe de points autour du rond qu'on vient de cocher. Rejouée à chaque changement de `trigger`.
struct CheckBurst: View {
    let trigger: Int
    let color: Color

    var body: some View {
        if trigger > 0 {
            BurstRing(color: color)
                .id(trigger)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct BurstRing: View {
    let color: Color
    @State private var spread = false

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Angle.degrees(Double(index) * 45)
                Circle()
                    .fill(index.isMultiple(of: 2) ? color : Palette.accentAlt)
                    .frame(width: 5, height: 5)
                    .offset(x: spread ? 22 * cos(angle.radians) : 0, y: spread ? 22 * sin(angle.radians) : 0)
                    .opacity(spread ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { spread = true }
        }
    }
}

/// Pluie de confettis sur toute la largeur, quelques secondes.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat
        let delay: Double
        let duration: Double
        let spin: Double
        let color: Color
        let size: CGSize
    }

    /// Tirés une fois : un nouveau rendu du parent ne fait pas sauter les confettis.
    @State private var pieces: [Piece] = (0..<36).map { index in
        let colors = [Palette.accent, Palette.accentAlt, SectionColors.at(1).vivid, SectionColors.at(2).vivid,
                      SectionColors.at(3).vivid, SectionColors.at(5).vivid]
        return Piece(id: index, x: .random(in: 0...1), delay: .random(in: 0...0.5),
                     duration: .random(in: 1.4...2.4), spin: .random(in: -540...540),
                     color: colors[index % colors.count],
                     size: CGSize(width: .random(in: 6...10), height: .random(in: 8...14)))
    }

    @State private var fall = false

    var body: some View {
        GeometryReader { geometry in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(piece.color)
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(fall ? piece.spin : 0))
                    .position(x: piece.x * geometry.size.width, y: fall ? geometry.size.height + 20 : -20)
                    .opacity(fall ? 0.15 : 1)
                    .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { fall = true }
    }
}

/// Barre de progression arrondie, en dégradé.
struct ProgressBar: View {
    /// Entre 0 et 1.
    let value: Double

    var body: some View {
        Capsule()
            .fill(Palette.control)
            .frame(height: 8)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.accent, Palette.accentAlt],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(value > 0 ? 8 : 0, geometry.size.width * min(max(value, 0), 1)))
                }
            }
            .animation(.spring(duration: 0.45), value: value)
            .accessibilityHidden(true)
    }
}
