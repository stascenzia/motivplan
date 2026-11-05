import SwiftUI
import UIKit

/// Appui long puis glisser pour réordonner une ligne de la frise (ADR-008), sans bloquer le
/// défilement.
///
/// Depuis iOS 18, un `DragGesture` SwiftUI posé sur le contenu d'une `ScrollView`, même en
/// `simultaneousGesture` derrière un appui long, capte le doigt : la frise ne défilait plus qu'en
/// glissant une tâche vers le bas (retour du 2026-11-05). Un appui long UIKit, lui, échoue dès que le
/// doigt bouge avant le délai : le défilement de la `ScrollView` passe, et le glisser ne démarre
/// qu'après l'appui long. iOS 17 garde le geste SwiftUI, qui n'avait pas ce défaut.
struct ReorderGesture<Legacy: Gesture>: ViewModifier {
    let enabled: Bool
    let legacy: Legacy
    /// Position verticale du doigt dans l'espace `DayTimeline.space`.
    let began: (CGFloat) -> Void
    let changed: (CGFloat) -> Void
    let ended: () -> Void

    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(LongPressDragRecognizer(began: began, changed: changed, ended: ended))
        } else {
            content.simultaneousGesture(legacy)
        }
    }
}

@available(iOS 18.0, *)
private struct LongPressDragRecognizer: UIGestureRecognizerRepresentable {
    let began: (CGFloat) -> Void
    let changed: (CGFloat) -> Void
    let ended: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.35
        // Au-delà, c'est un défilement : l'appui long échoue et la frise défile.
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let y = context.converter.location(in: .named(DayTimeline.space)).y
        switch recognizer.state {
        case .began: began(y)
        case .changed: changed(y)
        case .ended, .cancelled, .failed: ended()
        default: break
        }
    }
}
