import MemoryImport
import SwiftUI
import SyncClient
import UIKit

/// Jeton TMDB de l'utilisateur, rangé dans le trousseau (ADR-017) : jamais dans le code, le dépôt,
/// les journaux ni la synchro.
enum TMDBSettings {
    private static let service = "fr.ascenzia.motivplan.tmdb"
    private static let account = "readAccessToken"

    static var token: String? {
        get { Keychain.read(service: service, account: account) }
        set {
            let cleaned = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleaned, !cleaned.isEmpty {
                Keychain.write(cleaned, service: service, account: account)
            } else {
                Keychain.delete(service: service, account: account)
            }
        }
    }

    static var client: TMDBClient? {
        token.map { TMDBClient(token: $0) }
    }

    /// Mention exigée par les conditions d'utilisation de TMDB.
    static let attribution = "Ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB."
}

/// Affiches gardées en cache sur l'iPhone : téléchargées une fois, sans jeton (images publiques).
nonisolated enum PosterCache {
    private static var directory: URL {
        URL.cachesDirectory.appendingPathComponent("Posters", isDirectory: true)
    }

    private static func file(for path: String) -> URL {
        directory.appendingPathComponent(path.replacingOccurrences(of: "/", with: ""))
    }

    static func image(for path: String) async -> UIImage? {
        let file = file(for: path)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) { return image }
        guard let (data, response) = try? await URLSession.shared.data(from: TMDBClient.posterURL(path)),
              (response as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        return image
    }
}

/// Affiche d'un film ou d'une série, ou un pictogramme en attendant.
struct PosterImage: View {
    let path: String?
    var width: CGFloat = 46

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Palette.control
                    Image(systemName: "film").foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .frame(width: width, height: width * 1.5)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: path) {
            image = nil
            guard let path else { return }
            image = await PosterCache.image(for: path)
        }
        .accessibilityHidden(true)
    }
}

/// Recherche d'un film ou d'une série sur TMDB à partir du titre saisi : choisir un résultat remplit
/// le format, le genre, la plateforme en France, le résumé et l'affiche. Sans jeton ou sans réseau,
/// la fiche se remplit à la main comme avant.
struct TMDBSearchCard: View {
    /// Titre saisi, cherché tel quel.
    let query: String
    /// Affiche déjà choisie.
    let posterPath: String?
    /// Titre du résultat choisi et champs du modèle à poser.
    let apply: (String, [String: String]) -> Void

    @State private var results: [TMDBResult] = []
    @State private var searching = false
    @State private var loadingId: String?
    @State private var message: String?
    @State private var hasToken = TMDBSettings.token != nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if posterPath != nil {
                    PosterImage(path: posterPath, width: 40)
                }
                VStack(alignment: .leading, spacing: 2) {
                    CardTitle(text: "Fiche TMDB")
                    Text(hasToken ? "Résumé, genre et plateforme remplis pour toi." : "Colle ton jeton TMDB dans les réglages pour remplir la fiche.")
                        .font(.meta)
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer()
                if hasToken {
                    Button(searching ? "Recherche…" : "Chercher", systemImage: "magnifyingglass", action: search)
                        .buttonStyle(PillButtonStyle(prominent: true))
                        .disabled(trimmedQuery.isEmpty || searching)
                        .accessibilityIdentifier("tmdb-search")
                }
            }
            if !hasToken {
                Text("Compte gratuit sur themoviedb.org → Paramètres → API → « Jeton d'accès en lecture à l'API ». Puis Réglages de MotivPlan → Films et séries.")
                    .font(.meta)
                    .foregroundStyle(Palette.textSecondary)
            }
            if let message {
                Text(message)
                    .font(.meta)
                    .foregroundStyle(Color.gentleWarning)
            }
            ForEach(results) { result in
                resultRow(result)
            }
            if !results.isEmpty {
                Text("Données de TMDB")
                    .font(.meta)
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .card()
        .onAppear { hasToken = TMDBSettings.token != nil }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resultRow(_ result: TMDBResult) -> some View {
        Button {
            choose(result)
        } label: {
            HStack(spacing: 12) {
                PosterImage(path: result.posterPath)
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.title)
                        .font(.rowTitle)
                        .foregroundStyle(Palette.text)
                    Text([result.media == .movie ? "Film" : "Série", result.year].compactMap { $0 }.joined(separator: " · "))
                        .font(.meta)
                        .foregroundStyle(Palette.textSecondary)
                    if let overview = result.overview {
                        Text(overview)
                            .font(.meta)
                            .foregroundStyle(Palette.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if loadingId == result.id {
                    ProgressView()
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loadingId != nil)
    }

    private func search() {
        guard let client = TMDBSettings.client, !trimmedQuery.isEmpty else { return }
        searching = true
        message = nil
        Task {
            defer { searching = false }
            do {
                results = Array(try await client.search(trimmedQuery).prefix(6))
                if results.isEmpty { message = "Aucun film ni série trouvé pour « \(trimmedQuery) »." }
            } catch {
                results = []
                message = error.localizedDescription
            }
        }
    }

    private func choose(_ result: TMDBResult) {
        guard let client = TMDBSettings.client else { return }
        loadingId = result.id
        message = nil
        Task {
            defer { loadingId = nil }
            do {
                let details = try await client.details(of: result)
                apply(details.result.title.isEmpty ? result.title : details.result.title, TMDBMapping.fields(for: details))
                results = []
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
