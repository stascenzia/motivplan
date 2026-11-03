import Foundation
import TimelineEngine

/// Tâche décrite en entier avant sa création (bouton « + »). La capture rapide (Siri, widget,
/// champ de la boîte) reste un simple titre : `TaskStore.capture`.
public struct TaskDraft: Sendable, Equatable {
    public var title: String
    public var notes: String
    /// `nil` : « À trier ».
    public var sectionId: UUID?
    public var tag: TaskTag?
    public var dueDate: DayKey?
    /// Jour où poser la tâche tout de suite, si sa section se planifie.
    public var scheduledDate: DayKey?
    /// `nil` : durée suggérée par la section.
    public var durationMin: Minutes?

    public init(title: String = "", notes: String = "", sectionId: UUID? = nil, tag: TaskTag? = nil,
                dueDate: DayKey? = nil, scheduledDate: DayKey? = nil, durationMin: Minutes? = nil) {
        self.title = title
        self.notes = notes
        self.sectionId = sectionId
        self.tag = tag
        self.dueDate = dueDate
        self.scheduledDate = scheduledDate
        self.durationMin = durationMin
    }
}
