import CoreModels
import MemoryImport
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Extension de partage « MotivPlan » (ADR-017) : depuis Picnic, Safari ou Photos, une recette
/// (photos, texte ou lien) part dans les Recettes. L'extension n'ouvre pas le store : elle dépose
/// une fiche dans l'App Group, et l'app la découpe à sa prochaine ouverture.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let host = UIHostingController(rootView: ShareView(providers: providers) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

/// Contenu partagé, lu une fois.
struct SharedContent {
    var images: [Data] = []
    var url: String?
    var text: String?

    var isEmpty: Bool { images.isEmpty && url == nil && (text?.isEmpty ?? true) }

    var summary: String {
        if !images.isEmpty { return images.count == 1 ? "1 photo" : "\(images.count) photos" }
        if let url { return URL(string: url)?.host() ?? url }
        return String((text ?? "").prefix(140))
    }
}

struct ShareView: View {
    let providers: [NSItemProvider]
    let done: () -> Void

    private enum Stage { case loading, ready, saved, unavailable, failed }

    @State private var stage: Stage = .loading
    @State private var content = SharedContent()

    private var queue: PendingImportQueue? {
        PendingImportQueue(groupContainer: FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppGroup.identifier))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                switch stage {
                case .loading:
                    ProgressView()
                case .ready:
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Ajouter cette recette aux Recettes de MotivPlan ?")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text(content.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                    Text("MotivPlan repère les ingrédients et les étapes à sa prochaine ouverture. Tu pourras tout relire dans la fiche.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .saved:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                    Text("Ajoutée. Ouvre MotivPlan pour la retrouver dans Recettes.")
                        .multilineTextAlignment(.center)
                case .unavailable:
                    Text("Le partage n'est pas disponible avec cette installation de MotivPlan. Dans l'app, ouvre une recette et utilise « Importer une recette » (photos ou texte collé).")
                        .multilineTextAlignment(.center)
                case .failed:
                    Text("Rien à importer : partage une photo, un texte ou un lien de recette.")
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("MotivPlan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(stage == .saved ? "Fermer" : "Annuler", action: done)
                }
                if stage == .ready {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ajouter", action: save)
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard queue != nil else {
            stage = .unavailable
            return
        }
        var content = SharedContent()
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                if let data = await Self.data(from: provider, type: .image) { content.images.append(data) }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                if let url = await Self.url(from: provider) { content.url = url }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                if let text = await Self.text(from: provider) {
                    content.text = [content.text, text].compactMap { $0 }.joined(separator: "\n")
                }
            }
        }
        self.content = content
        stage = content.isEmpty ? .failed : .ready
    }

    private func save() {
        guard let queue else {
            stage = .unavailable
            return
        }
        do {
            try queue.enqueue(text: content.text, url: content.url, images: content.images)
            stage = .saved
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                done()
            }
        } catch {
            stage = .unavailable
        }
    }

    // MARK: Lecture des pièces jointes

    private static func data(from provider: NSItemProvider, type: UTType) async -> Data? {
        await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func url(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url?.absoluteString)
            }
        }
    }

    private static func text(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in
                continuation.resume(returning: text)
            }
        }
    }
}
