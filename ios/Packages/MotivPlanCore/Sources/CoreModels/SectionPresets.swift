import Foundation

/// Sections fournies au premier lancement (ADR-014). Toutes modifiables ensuite.
public struct SectionPreset: Sendable {
    public let name: String
    public let symbol: String
    public let defaultDuration: Int?
    public let isPlannable: Bool
    public let keepsMemory: Bool
    public let repeatRule: SectionRepeat

    public static let all: [SectionPreset] = [
        SectionPreset(name: "Quotidiennes", symbol: "sunrise", defaultDuration: 15,
                      isPlannable: true, keepsMemory: false, repeatRule: .daily),
        SectionPreset(name: "Récurrentes", symbol: "arrow.trianglehead.2.clockwise", defaultDuration: 30,
                      isPlannable: true, keepsMemory: false, repeatRule: .permanent),
        SectionPreset(name: "Ponctuelles", symbol: "checkmark.circle", defaultDuration: 30,
                      isPlannable: true, keepsMemory: false, repeatRule: .none),
        SectionPreset(name: "Courses", symbol: "cart", defaultDuration: nil,
                      isPlannable: false, keepsMemory: false, repeatRule: .none),
        SectionPreset(name: "Recettes", symbol: "fork.knife", defaultDuration: 60,
                      isPlannable: false, keepsMemory: true, repeatRule: .none),
        SectionPreset(name: "Films et séries", symbol: "film", defaultDuration: nil,
                      isPlannable: false, keepsMemory: true, repeatRule: .none),
    ]
}
