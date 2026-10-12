import Foundation

/// Indices de séquence à trous : un réordonnancement réécrit en général un seul item (cahier §3.1).
public enum OrderIndex {
    public static let step = 1024
    /// En dessous de cet écart entre deux voisins, toute la séquence est renumérotée.
    public static let minGap = 2

    /// Indice à donner à un item ajouté en fin de séquence.
    public static func appended(after existing: [Int]) -> Int {
        (existing.max() ?? 0) + step
    }

    /// Calcule les indices qui donnent l'ordre `target`, en réécrivant le moins d'items possible.
    ///
    /// Les items dont l'indice actuel suit déjà l'ordre voulu (plus longue sous-suite croissante)
    /// gardent leur indice ; les autres sont placés dans les trous. S'il n'y a plus de place,
    /// toute la séquence est renumérotée par pas de `step`.
    /// - Returns: uniquement les items dont l'indice change (ou qui n'en avaient pas).
    public static func reindex(target: [UUID], current: [UUID: Int]) -> [UUID: Int] {
        let values = target.map { current[$0] }
        let kept = longestIncreasingRun(values)

        var assigned: [Int] = values.map { $0 ?? 0 }
        var position = 0
        while position < target.count {
            if kept.contains(position) {
                position += 1
                continue
            }
            let runStart = position
            while position < target.count, !kept.contains(position) { position += 1 }
            let runLength = position - runStart
            let low = runStart > 0 ? assigned[runStart - 1] : nil
            let high = position < target.count ? values[position] : nil

            switch (low, high) {
            case (nil, nil):
                for offset in 0..<runLength { assigned[runStart + offset] = step * (offset + 1) }
            case (let low?, nil):
                for offset in 0..<runLength { assigned[runStart + offset] = low + step * (offset + 1) }
            case (nil, let high?):
                for offset in 0..<runLength { assigned[runStart + offset] = high - step * (runLength - offset) }
            case (let low?, let high?):
                guard (high - low) / (runLength + 1) >= minGap else {
                    return renumbered(target: target, current: current)
                }
                for offset in 0..<runLength {
                    assigned[runStart + offset] = low + (high - low) * (offset + 1) / (runLength + 1)
                }
            }
        }

        return changes(target: target, assigned: assigned, current: current)
    }

    static func renumbered(target: [UUID], current: [UUID: Int]) -> [UUID: Int] {
        changes(target: target, assigned: target.indices.map { step * ($0 + 1) }, current: current)
    }

    private static func changes(target: [UUID], assigned: [Int], current: [UUID: Int]) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for (id, value) in zip(target, assigned) where current[id] != value {
            result[id] = value
        }
        return result
    }

    /// Positions d'une plus longue sous-suite strictement croissante parmi les valeurs connues.
    private static func longestIncreasingRun(_ values: [Int?]) -> Set<Int> {
        var length = Array(repeating: 0, count: values.count)
        var previous = Array(repeating: -1, count: values.count)
        var best = -1

        for i in values.indices {
            guard let value = values[i] else { continue }
            length[i] = 1
            for j in 0..<i {
                if let other = values[j], other < value, length[j] + 1 > length[i] {
                    length[i] = length[j] + 1
                    previous[i] = j
                }
            }
            if best == -1 || length[i] > length[best] { best = i }
        }

        var kept = Set<Int>()
        var cursor = best
        while cursor != -1 {
            kept.insert(cursor)
            cursor = previous[cursor]
        }
        return kept
    }
}
