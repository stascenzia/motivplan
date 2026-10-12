import Foundation

public enum TaskStatus: String, Sendable, Hashable, CaseIterable, Codable {
    case inbox, scheduled, done, archived
}

/// Vue réduite d'une tâche pour le report automatique.
public struct RolloverTask: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var status: TaskStatus
    public var scheduledDate: DayKey?
    public var orderIndex: Int?
    public var anchorStart: Minutes?
    public var dueDate: DayKey?
    public var postponeCount: Int

    public init(id: UUID, status: TaskStatus, scheduledDate: DayKey? = nil, orderIndex: Int? = nil,
                anchorStart: Minutes? = nil, dueDate: DayKey? = nil, postponeCount: Int = 0) {
        self.id = id
        self.status = status
        self.scheduledDate = scheduledDate
        self.orderIndex = orderIndex
        self.anchorStart = anchorStart
        self.dueDate = dueDate
        self.postponeCount = postponeCount
    }

    public var isAnchored: Bool { anchorStart != nil }
}

/// Report automatique silencieux (cahier §3.3, ADR-007).
public enum Rollover {
    /// Tâches `scheduled` posées sur un jour passé :
    /// - flottantes → aujourd'hui, à la suite des tâches déjà posées, ordre `(jour, orderIndex)` conservé,
    ///   `postponeCount` +1 ;
    /// - ancrées → boîte de réception, désancrées, `dueDate` = ancien jour si elle était vide.
    ///
    /// Idempotent : un second appel le même jour ne trouve plus rien à reporter.
    /// - Returns: uniquement les tâches modifiées, avec leurs nouvelles valeurs.
    public static func apply(to tasks: [RolloverTask], today: DayKey) -> [RolloverTask] {
        let overdue = tasks
            .filter { $0.status == .scheduled && ($0.scheduledDate.map { $0 < today } ?? false) }
            .sorted { ($0.scheduledDate!, $0.orderIndex ?? 0, $0.id.uuidString)
                    < ($1.scheduledDate!, $1.orderIndex ?? 0, $1.id.uuidString) }

        var nextIndex = OrderIndex.appended(
            after: tasks.filter { $0.scheduledDate == today }.compactMap(\.orderIndex))

        return overdue.map { task in
            var moved = task
            if task.isAnchored {
                moved.status = .inbox
                moved.dueDate = task.dueDate ?? task.scheduledDate
                moved.scheduledDate = nil
                moved.orderIndex = nil
                moved.anchorStart = nil
            } else {
                moved.scheduledDate = today
                moved.orderIndex = nextIndex
                moved.postponeCount += 1
                nextIndex += OrderIndex.step
            }
            return moved
        }
    }
}
