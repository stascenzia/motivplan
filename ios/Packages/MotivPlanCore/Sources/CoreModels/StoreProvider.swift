import Foundation
import SwiftData

/// Ouverture du store, une fois par processus. Peut échouer avant le premier déverrouillage
/// après un redémarrage (fichiers protégés) : l'app affiche alors un message, Siri le dit,
/// au lieu de planter.
public final class StoreProvider: Sendable {
    public let result: Result<ModelContainer, any Error>

    public init(inMemory: Bool = false) {
        result = Result { try Persistence.makeContainer(inMemory: inMemory) }
    }

    public var container: ModelContainer? {
        try? result.get()
    }
}
