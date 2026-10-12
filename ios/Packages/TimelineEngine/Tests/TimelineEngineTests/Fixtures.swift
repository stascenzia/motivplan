import Foundation
@testable import TimelineEngine

/// "10:30" → 630.
func hm(_ text: String) -> Minutes {
    let parts = text.split(separator: ":").map { Int($0)! }
    return parts[0] * 60 + parts[1]
}

func clock(_ minutes: Minutes) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
}

/// Journée décrite par des noms lisibles : `.float("A", 30)`, `.anchor("M", "10:00", 60)`.
enum Spec {
    case float(String, Minutes)
    case anchor(String, String, Minutes)
}

struct Day {
    var items: [TimelineItem]
    let ids: [String: UUID]

    init(_ specs: [Spec]) {
        var ids: [String: UUID] = [:]
        var items: [TimelineItem] = []
        for (position, spec) in specs.enumerated() {
            let index = (position + 1) * OrderIndex.step
            switch spec {
            case let .float(name, duration):
                let id = UUID()
                ids[name] = id
                items.append(TimelineItem(id: id, orderIndex: index, durationMin: duration))
            case let .anchor(name, start, duration):
                let id = UUID()
                ids[name] = id
                items.append(TimelineItem(id: id, orderIndex: index, durationMin: duration, anchorStart: hm(start)))
            }
        }
        self.items = items
        self.ids = ids
    }

    func layout(dayStart: Minutes = TimelineEngine.defaultDayStart) -> DayLayout {
        TimelineEngine.layoutDay(dayStart: dayStart, items: items)
    }

    func name(of id: UUID) -> String {
        ids.first { $0.value == id }!.key
    }

    /// Ordre affiché, en noms.
    func sequence(dayStart: Minutes = TimelineEngine.defaultDayStart) -> [String] {
        layout(dayStart: dayStart).sequence.map(name(of:))
    }

    /// Heures de début affichées, par nom.
    func starts(dayStart: Minutes = TimelineEngine.defaultDayStart) -> [String: String] {
        Dictionary(uniqueKeysWithValues: layout(dayStart: dayStart).placements.map { (name(of: $0.id), clock($0.start)) })
    }

    func placement(_ name: String) -> Placement {
        layout().placements.first { $0.id == ids[name] }!
    }

    mutating func apply(_ changes: [UUID: Int]) {
        for index in items.indices {
            if let value = changes[items[index].id] { items[index].orderIndex = value }
        }
    }

    mutating func setDuration(_ name: String, _ duration: Minutes) {
        let index = items.firstIndex { $0.id == ids[name] }!
        items[index].durationMin = duration
    }
}

/// Générateur pseudo-aléatoire reproductible (SplitMix64), pour les tests de propriétés.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
