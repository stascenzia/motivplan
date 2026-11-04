import Foundation
import TimelineEngine

/// Tâche décrite en entier avant sa création (bouton « + »). La capture rapide (Siri, widget,
/// champ de la boîte) reste un simple titre : `TaskStore.capture`.
public struct TaskDraft: Sendable, Equatable {
    public var title: String
    public var notes: String
    /// `nil` : « À trier » de l'espace choisi.
    public var sectionId: UUID?
    /// Espace d'une entrée sans section : boîte de réception ou Mémoire (ADR-016).
    public var space: TaskSpace
    public var tag: TaskTag?
    public var dueDate: DayKey?
    /// Jour où poser la tâche tout de suite, si sa section se planifie.
    public var scheduledDate: DayKey?
    /// `nil` : durée suggérée par la section.
    public var durationMin: Minutes?
    /// Période (section de type `periods`), bornes incluses.
    public var startDate: DayKey?
    public var endDate: DayKey?
    /// Titres des sous-tâches, dans l'ordre ; les lignes vides sont ignorées.
    public var subtasks: [String]
    /// Champs du modèle de la section ; les valeurs vides sont ignorées.
    public var fields: [String: String]

    public init(title: String = "", notes: String = "", sectionId: UUID? = nil, space: TaskSpace = .tasks,
                tag: TaskTag? = nil, dueDate: DayKey? = nil, scheduledDate: DayKey? = nil,
                durationMin: Minutes? = nil, startDate: DayKey? = nil, endDate: DayKey? = nil,
                subtasks: [String] = [], fields: [String: String] = [:]) {
        self.title = title
        self.notes = notes
        self.sectionId = sectionId
        self.space = space
        self.tag = tag
        self.dueDate = dueDate
        self.scheduledDate = scheduledDate
        self.durationMin = durationMin
        self.startDate = startDate
        self.endDate = endDate
        self.subtasks = subtasks
        self.fields = fields
    }
}
