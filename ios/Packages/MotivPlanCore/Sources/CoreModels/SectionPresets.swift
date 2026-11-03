import Foundation

/// Sections fournies au premier lancement (ADR-014, types d'ADR-015). Toutes modifiables ensuite.
public struct SectionPreset: Sendable {
    public let name: String
    public let symbol: String
    public let defaultDuration: Int?
    public let isPlannable: Bool
    public let keepsMemory: Bool
    public let repeatRule: SectionRepeat
    public let kind: SectionKind

    public static let all: [SectionPreset] = [
        SectionPreset(name: "Quotidiennes", symbol: "sunrise", defaultDuration: 15,
                      isPlannable: true, keepsMemory: false, repeatRule: .daily, kind: .tasks),
        SectionPreset(name: "Récurrentes", symbol: "arrow.trianglehead.2.clockwise", defaultDuration: 30,
                      isPlannable: true, keepsMemory: false, repeatRule: .permanent, kind: .tasks),
        SectionPreset(name: "Ponctuelles", symbol: "checkmark.circle", defaultDuration: 30,
                      isPlannable: true, keepsMemory: false, repeatRule: .none, kind: .tasks),
        SectionPreset(name: "Courses", symbol: "cart", defaultDuration: nil,
                      isPlannable: false, keepsMemory: false, repeatRule: .none, kind: .checklist),
        SectionPreset(name: "Recettes", symbol: "fork.knife", defaultDuration: 60,
                      isPlannable: false, keepsMemory: true, repeatRule: .none, kind: .memory),
        SectionPreset(name: "Films et séries", symbol: "film", defaultDuration: nil,
                      isPlannable: false, keepsMemory: true, repeatRule: .none, kind: .memory),
        SectionPreset(name: "Voyages", symbol: "airplane", defaultDuration: nil,
                      isPlannable: false, keepsMemory: false, repeatRule: .none, kind: .periods),
    ]
}
