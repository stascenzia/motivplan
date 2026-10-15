import CoreModels
import Foundation

// Conversion entre les modèles SwiftData et le format de l'API. Appliquer un enregistrement distant
// ne pose pas `needsSync` : il vient du serveur, il n'y a rien à renvoyer.

extension TaskItem {
    public var dto: TaskDTO {
        TaskDTO(
            id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt,
            title: title, notes: notes, sectionId: sectionId, tag: tagRaw, dueDate: dueDate,
            durationMin: durationMin, status: statusRaw, scheduledDate: scheduledDate,
            orderIndex: orderIndex, isAnchored: isAnchored && anchorTime != nil,
            anchorTime: anchorTime.map(SyncCoding.time(fromMinutes:)), completedAt: completedAt,
            postponeCount: postponeCount, source: sourceRaw, review: reviewRaw, reviewNote: reviewNote,
            serverUpdatedAt: nil)
    }

    func apply(_ remote: TaskDTO) {
        createdAt = remote.createdAt
        updatedAt = remote.updatedAt
        deletedAt = remote.deletedAt
        title = remote.title
        notes = remote.notes
        sectionId = remote.sectionId
        tagRaw = remote.tag
        dueDate = remote.dueDate
        durationMin = remote.durationMin
        statusRaw = remote.status
        scheduledDate = remote.scheduledDate
        orderIndex = remote.orderIndex
        anchorTime = remote.anchorTime.flatMap(SyncCoding.minutes(fromTime:))
        isAnchored = remote.isAnchored && anchorTime != nil
        completedAt = remote.completedAt
        postponeCount = remote.postponeCount
        sourceRaw = remote.source
        reviewRaw = remote.review
        reviewNote = remote.reviewNote
        needsSync = false
    }

    static func make(from remote: TaskDTO) -> TaskItem {
        let task = TaskItem(id: remote.id, title: remote.title,
                            source: TaskSource(rawValue: remote.source) ?? .manual, now: remote.createdAt)
        task.apply(remote)
        return task
    }
}

extension TaskSection {
    public var dto: SectionDTO {
        SectionDTO(
            id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, name: name,
            symbol: symbol, sortIndex: sortIndex, defaultDuration: defaultDuration,
            isPlannable: isPlannable, keepsMemory: keepsMemory, repeat: repeatRaw, serverUpdatedAt: nil)
    }

    func apply(_ remote: SectionDTO) {
        createdAt = remote.createdAt
        updatedAt = remote.updatedAt
        deletedAt = remote.deletedAt
        name = remote.name
        symbol = remote.symbol
        sortIndex = remote.sortIndex
        defaultDuration = remote.defaultDuration
        isPlannable = remote.isPlannable
        keepsMemory = remote.keepsMemory
        repeatRaw = remote.repeat
        needsSync = false
    }

    static func make(from remote: SectionDTO) -> TaskSection {
        let section = TaskSection(
            id: remote.id, name: remote.name, symbol: remote.symbol, sortIndex: remote.sortIndex,
            defaultDuration: remote.defaultDuration, isPlannable: remote.isPlannable,
            keepsMemory: remote.keepsMemory, repeatRule: SectionRepeat(rawValue: remote.repeat) ?? .none,
            now: remote.createdAt)
        section.apply(remote)
        return section
    }
}

extension WorkSession {
    public var dto: SessionDTO {
        SessionDTO(
            id: id, createdAt: createdAt, updatedAt: updatedAt, deletedAt: deletedAt, taskId: taskId,
            scheduledDate: scheduledDate, orderIndex: orderIndex, durationMin: durationMin,
            completedAt: completedAt, serverUpdatedAt: nil)
    }

    func apply(_ remote: SessionDTO) {
        createdAt = remote.createdAt
        updatedAt = remote.updatedAt
        deletedAt = remote.deletedAt
        taskId = remote.taskId
        scheduledDate = remote.scheduledDate
        orderIndex = remote.orderIndex
        durationMin = remote.durationMin
        completedAt = remote.completedAt
        needsSync = false
    }

    static func make(from remote: SessionDTO) -> WorkSession {
        let session = WorkSession(
            id: remote.id, taskId: remote.taskId, scheduledDate: remote.scheduledDate,
            orderIndex: remote.orderIndex, durationMin: remote.durationMin, now: remote.createdAt)
        session.apply(remote)
        return session
    }
}
