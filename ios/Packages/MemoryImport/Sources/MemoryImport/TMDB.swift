import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fiches de films et séries depuis TMDB (The Movie Database), gratuit pour un usage personnel
/// (ADR-017). L'utilisateur colle son « jeton d'accès en lecture » dans les réglages ; il reste
/// dans le trousseau de l'iPhone, jamais dans le code ni dans la synchro.
public enum TMDBMedia: String, Sendable, Hashable, Codable {
    case movie, tv
}

/// Un résultat de recherche.
public struct TMDBResult: Sendable, Hashable, Identifiable {
    public let tmdbId: Int
    public let media: TMDBMedia
    public let title: String
    public let year: String?
    public let overview: String?
    public let posterPath: String?

    public init(tmdbId: Int, media: TMDBMedia, title: String, year: String?, overview: String?, posterPath: String?) {
        self.tmdbId = tmdbId
        self.media = media
        self.title = title
        self.year = year
        self.overview = overview
        self.posterPath = posterPath
    }

    /// « movie:438631 » : identifiant stable, gardé dans les champs de l'entrée.
    public var id: String { "\(media.rawValue):\(tmdbId)" }
}

/// Fiche complète : genres et plateformes d'abonnement en France.
public struct TMDBDetails: Sendable, Equatable {
    public let result: TMDBResult
    public let genres: [String]
    /// Plateformes d'abonnement (« flatrate »), par ordre d'importance donné par TMDB.
    public let providers: [String]
    /// Nombre de saisons d'une série ; `nil` pour un film.
    public var seasons: Int? = nil
}

public enum TMDBError: Error, Equatable, LocalizedError {
    case unauthorized
    case server(Int)
    case network
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Jeton TMDB refusé. Vérifie-le dans les réglages."
        case .server(let code): "TMDB ne répond pas (erreur \(code)). Réessaie plus tard."
        case .network: "Pas de connexion. Tu peux remplir la fiche à la main."
        case .badResponse: "Réponse de TMDB illisible."
        }
    }
}

// MARK: - Décodage

public enum TMDBDecoding {
    private struct SearchPage: Decodable {
        let results: [Item]
    }

    private struct Item: Decodable {
        let id: Int
        let media_type: String?
        let title: String?
        let name: String?
        let release_date: String?
        let first_air_date: String?
        let overview: String?
        let poster_path: String?
    }

    private struct Details: Decodable {
        struct Genre: Decodable { let name: String }
        struct Providers: Decodable {
            struct Country: Decodable {
                struct Provider: Decodable { let provider_name: String }
                let flatrate: [Provider]?
            }
            let results: [String: Country]
        }

        let id: Int
        let title: String?
        let name: String?
        let release_date: String?
        let first_air_date: String?
        let overview: String?
        let poster_path: String?
        let genres: [Genre]?
        let number_of_seasons: Int?
        let providers: Providers?

        enum CodingKeys: String, CodingKey {
            case id, title, name, release_date, first_air_date, overview, poster_path, genres, number_of_seasons
            case providers = "watch/providers"
        }
    }

    /// Films et séries seulement (la recherche « multi » renvoie aussi des personnes).
    public static func searchResults(from data: Data) throws -> [TMDBResult] {
        guard let page = try? JSONDecoder().decode(SearchPage.self, from: data) else { throw TMDBError.badResponse }
        return page.results.compactMap { item in
            guard let media = item.media_type.flatMap(TMDBMedia.init(rawValue:)),
                  let title = item.title ?? item.name, !title.isEmpty else { return nil }
            return TMDBResult(tmdbId: item.id, media: media, title: title,
                              year: year(item.release_date ?? item.first_air_date),
                              overview: nonEmpty(item.overview), posterPath: nonEmpty(item.poster_path))
        }
    }

    public static func details(from data: Data, media: TMDBMedia, region: String = "FR") throws -> TMDBDetails {
        guard let item = try? JSONDecoder().decode(Details.self, from: data) else { throw TMDBError.badResponse }
        let result = TMDBResult(tmdbId: item.id, media: media, title: item.title ?? item.name ?? "",
                                year: year(item.release_date ?? item.first_air_date),
                                overview: nonEmpty(item.overview), posterPath: nonEmpty(item.poster_path))
        let providers = item.providers?.results[region]?.flatrate?.map(\.provider_name) ?? []
        let seasons = media == .tv ? item.number_of_seasons.flatMap { $0 > 0 ? $0 : nil } : nil
        return TMDBDetails(result: result, genres: item.genres?.map(\.name) ?? [], providers: providers,
                           seasons: seasons)
    }

    private static func year(_ date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}

// MARK: - Champs de la fiche

/// Traduction d'une fiche TMDB en champs du modèle « Films et séries » (clés de `fieldsRaw`).
public enum TMDBMapping {
    public static let formatKey = "format"
    public static let genreKey = "genre"
    /// Tous les genres, un par ligne, aux noms de l'app.
    public static let genresKey = "genres"
    public static let platformKey = "platform"
    /// Nombre de saisons d'une série.
    public static let seasonsKey = "seasons"
    public static let summaryKey = "summary"
    /// « movie:438631 ».
    public static let idKey = "tmdb"
    /// Chemin de l'affiche chez TMDB, l'image elle-même est gardée en cache sur l'iPhone.
    public static let posterKey = "poster"

    public static func fields(for details: TMDBDetails) -> [String: String] {
        var fields: [String: String] = [
            formatKey: details.result.media == .movie ? "Film" : "Série",
            idKey: details.result.id,
        ]
        fields[genreKey] = genre(from: details.genres)
        // Tous les genres, un par ligne : `genres` porte le choix multiple, `genre` garde le premier
        // pour les versions précédentes de l'app.
        let all = genres(from: details.genres)
        if !all.isEmpty { fields[genresKey] = all.joined(separator: "\n") }
        fields[platformKey] = platform(from: details.providers)
        fields[seasonsKey] = details.seasons.map(String.init)
        fields[summaryKey] = details.result.overview
        fields[posterKey] = details.result.posterPath
        return fields
    }

    /// Premier genre de TMDB qui correspond à un genre proposé par l'app, sinon le premier tel quel.
    public static func genre(from genres: [String]) -> String? {
        genres.lazy.compactMap(knownGenre).first ?? genres.first
    }

    /// Chaque genre au nom de l'app quand il en a un, sans doublon, dans l'ordre de TMDB.
    public static func genres(from genres: [String]) -> [String] {
        var result: [String] = []
        for genre in genres {
            let name = knownGenre(genre) ?? genre
            if !result.contains(name) { result.append(name) }
        }
        return result
    }

    private static func knownGenre(_ genre: String) -> String? {
        let known: [(String, String)] = [
            ("science-fiction", "Science-fiction"), ("science fiction", "Science-fiction"),
            ("action", "Action"), ("animation", "Animation"), ("aventure", "Aventure"),
            ("adventure", "Aventure"), ("comedie", "Comédie"), ("comedy", "Comédie"),
            ("documentaire", "Documentaire"), ("documentary", "Documentaire"), ("drame", "Drame"),
            ("drama", "Drame"), ("horreur", "Horreur"), ("horror", "Horreur"), ("crime", "Policier"),
            ("policier", "Policier"), ("romance", "Romance"), ("thriller", "Thriller"),
            ("mystere", "Thriller"), ("mystery", "Thriller"),
        ]
        let folded = fold(genre)
        return known.first { folded.hasPrefix($0.0) }?.1
    }

    /// Plateforme la plus importante, au nom proposé par l'app (« Disney Plus » → « Disney+ »).
    public static func platform(from providers: [String]) -> String? {
        guard let first = providers.first else { return nil }
        let folded = fold(first)
        if folded.contains("netflix") { return "Netflix" }
        if folded.contains("prime video") || folded.contains("amazon") { return "Prime Video" }
        if folded.contains("disney") { return "Disney+" }
        if folded.contains("canal") { return "Canal+" }
        if folded.contains("apple tv") { return "Apple TV+" }
        if folded == "max" || folded.contains("hbo") { return "HBO Max" }
        if folded.contains("arte") { return "Arte" }
        return first
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR")).lowercased()
    }
}

// MARK: - Client

public struct TMDBClient: Sendable {
    public static let baseURL = URL(string: "https://api.themoviedb.org/3")!
    public static let imageBaseURL = URL(string: "https://image.tmdb.org/t/p")!

    private let token: String
    private let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    /// Recherche en français, films et séries mélangés.
    public func search(_ query: String) async throws -> [TMDBResult] {
        let request = Self.searchRequest(query, token: token)
        return try TMDBDecoding.searchResults(from: await send(request))
    }

    /// Fiche en français avec les plateformes de France, en une seule requête.
    public func details(of result: TMDBResult) async throws -> TMDBDetails {
        let request = Self.detailsRequest(result, token: token)
        return try TMDBDecoding.details(from: await send(request), media: result.media)
    }

    /// Affiche en petite taille (w342 : nette sur l'écran, légère).
    public static func posterURL(_ path: String, size: String = "w342") -> URL {
        imageBaseURL.appendingPathComponent(size).appendingPathComponent(path)
    }

    static func searchRequest(_ query: String, token: String) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent("search/multi"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "language", value: "fr-FR"),
            URLQueryItem(name: "include_adult", value: "false"),
        ]
        return authorized(components.url!, token: token)
    }

    static func detailsRequest(_ result: TMDBResult, token: String) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent("\(result.media.rawValue)/\(result.tmdbId)"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "language", value: "fr-FR"),
            URLQueryItem(name: "append_to_response", value: "watch/providers"),
        ]
        return authorized(components.url!, token: token)
    }

    private static func authorized(_ url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                session.dataTask(with: request) { data, response, error in
                    if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: error ?? TMDBError.network)
                    }
                }.resume()
            }
        } catch {
            throw TMDBError.network
        }
        guard let http = response as? HTTPURLResponse else { throw TMDBError.badResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw TMDBError.unauthorized
        default: throw TMDBError.server(http.statusCode)
        }
    }
}
