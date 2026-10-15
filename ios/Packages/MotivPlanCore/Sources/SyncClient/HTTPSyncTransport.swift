import Foundation

public enum SyncError: Error, Equatable, LocalizedError {
    case notConfigured
    case unauthorized
    case serverNotConfigured
    case http(Int)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "Adresse du serveur ou jeton manquant."
        case .unauthorized: "Jeton refusé par le serveur."
        case .serverNotConfigured: "Le serveur n'a pas de jeton configuré."
        case .http(let code): "Le serveur a répondu avec l'erreur \(code)."
        case .invalidResponse: "Réponse du serveur illisible."
        }
    }
}

/// `POST /sync` avec le jeton statique en en-tête (ADR-009).
public struct HTTPSyncTransport: SyncTransport {
    public let baseURL: URL
    public let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public func send(_ request: SyncRequestDTO) async throws -> SyncResponseDTO {
        var urlRequest = URLRequest(url: baseURL.appending(path: "sync"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try SyncCoding.encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
        switch http.statusCode {
        case 200:
            do {
                return try SyncCoding.decoder.decode(SyncResponseDTO.self, from: data)
            } catch {
                throw SyncError.invalidResponse
            }
        case 401: throw SyncError.unauthorized
        case 503: throw SyncError.serverNotConfigured
        default: throw SyncError.http(http.statusCode)
        }
    }
}
