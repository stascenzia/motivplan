import AppIntents
import CoreModels
import Foundation
import SwiftData
import WidgetKit

/// Capture Siri en deux temps (ADR-003) : « Ajoute une tâche dans MotivPlan », puis
/// Siri demande « Quelle tâche ? ». Pas d'ouverture de l'app : l'intent tourne en arrière-plan
/// dans le processus de l'app, seul écrivain du store (ADR-006). Aussi disponible dans
/// Raccourcis et sur le bouton Action.
public struct AddTaskIntent: AppIntent {
    public static let title: LocalizedStringResource = "Ajouter une tâche"
    public static let description = IntentDescription("Ajoute une tâche dans la boîte de réception de MotivPlan.")

    @available(iOS 26.0, macOS 26.0, *)
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Tâche", requestValueDialog: IntentDialog("Quelle tâche ?"))
    public var taskTitle: String

    @Dependency private var provider: StoreProvider

    public init() {}

    public init(taskTitle: String) {
        self.taskTitle = taskTitle
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = provider.container else {
            throw AddTaskError.storeUnavailable
        }
        let spoken = taskTitle
        let saved: String? = try await MainActor.run {
            let store = TaskStore(context: container.mainContext)
            do {
                return try store.capture(spoken, source: .siri).title
            } catch TaskStore.StoreError.emptyTitle {
                return nil
            }
        }
        guard let saved else {
            return .result(dialog: "Je n'ai rien entendu à ajouter.")
        }
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroup.captureWidgetKind)
        return .result(dialog: "Ajouté : \(saved)")
    }
}

enum AddTaskError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            "MotivPlan n'est pas accessible pour l'instant. Déverrouille ton iPhone, puis réessaie."
        }
    }
}

/// Exposé à l'app par `includedPackages` : l'app déclare les raccourcis Siri.
public struct CoreIntentsPackage: AppIntentsPackage {}
