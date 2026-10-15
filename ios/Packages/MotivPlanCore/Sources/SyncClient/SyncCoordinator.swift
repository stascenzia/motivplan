import CoreModels
import Foundation
import Observation
import SwiftData

/// Déclencheurs de synchro (plan, §Synchronisation) : passage au premier plan, 2 s après une
/// modification locale, rafraîchissement d'arrière-plan. La synchro n'est jamais sur le chemin
/// d'une action : un échec laisse les drapeaux en place pour la fois suivante.
@MainActor
@Observable
public final class SyncCoordinator {
    public enum Status: Equatable {
        case notConfigured
        case idle
        case syncing
        case failed(String)
    }

    public private(set) var status: Status = .idle
    public private(set) var lastSuccess: Date?

    private let container: ModelContainer
    private let makeTransport: () -> (any SyncTransport)?
    private let debounceDelay: Duration
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var saveObserver: (any NSObjectProtocol)?

    public init(container: ModelContainer, debounceDelay: Duration = .seconds(2),
                makeTransport: @escaping () -> (any SyncTransport)? = { SyncSettings.transport() }) {
        self.container = container
        self.debounceDelay = debounceDelay
        self.makeTransport = makeTransport
        if makeTransport() == nil { status = .notConfigured }
    }

    /// Écoute les sauvegardes du store pour synchroniser peu après chaque modification.
    public func start() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: container.mainContext, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                // Les sauvegardes faites par la synchro elle-même ne relancent pas de synchro.
                guard let self, self.status != .syncing else { return }
                self.syncSoon()
            }
        }
    }

    public func syncSoon() {
        debounce?.cancel()
        debounce = Task { [weak self, debounceDelay] in
            try? await Task.sleep(for: debounceDelay)
            guard !Task.isCancelled else { return }
            await self?.syncNow()
        }
    }

    public func syncNow() async {
        guard status != .syncing else { return }
        guard let transport = makeTransport() else {
            status = .notConfigured
            return
        }
        status = .syncing
        do {
            try await SyncEngine(context: container.mainContext, transport: transport).sync()
            lastSuccess = .now
            status = .idle
        } catch {
            status = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Après un changement de réglages.
    public func refreshConfiguration() {
        if makeTransport() == nil {
            status = .notConfigured
        } else if status == .notConfigured {
            status = .idle
        }
    }
}
