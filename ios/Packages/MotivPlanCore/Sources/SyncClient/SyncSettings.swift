import CoreModels
import Foundation
import Security

/// Réglages de synchro : adresse du serveur dans les UserDefaults, jeton dans le trousseau (ADR-009).
public enum SyncSettings {
    private static let serverURLKey = "sync.serverURL"
    private static let keychainService = "fr.ascenzia.motivplan.sync"
    private static let keychainAccount = "token"

    public static var serverURL: URL? {
        get {
            AppGroup.defaults.string(forKey: serverURLKey).flatMap(URL.init(string:))
        }
        set {
            AppGroup.defaults.set(newValue?.absoluteString, forKey: serverURLKey)
        }
    }

    public static var token: String? {
        get { Keychain.read(service: keychainService, account: keychainAccount) }
        set {
            if let newValue, !newValue.isEmpty {
                Keychain.write(newValue, service: keychainService, account: keychainAccount)
            } else {
                Keychain.delete(service: keychainService, account: keychainAccount)
            }
        }
    }

    /// Transport prêt à l'emploi, ou `nil` si la synchro n'est pas réglée.
    public static func transport() -> HTTPSyncTransport? {
        guard let serverURL, let token, !token.isEmpty else { return nil }
        return HTTPSyncTransport(baseURL: serverURL, token: token)
    }

    /// « api.exemple.fr » ou « https://api.exemple.fr/ » → URL https normalisée.
    public static func normalizedURL(_ text: String) -> URL? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if !cleaned.contains("://") { cleaned = "https://" + cleaned }
        while cleaned.hasSuffix("/") { cleaned.removeLast() }
        guard let url = URL(string: cleaned), url.host() != nil else { return nil }
        return url
    }
}

/// Mot de passe générique dans le trousseau, lisible après le premier déverrouillage
/// (la synchro d'arrière-plan doit pouvoir le lire).
enum Keychain {
    static func read(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ value: String, service: String, account: String) {
        delete(service: service, account: account)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8),
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
