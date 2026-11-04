import Foundation

/// Ce que l'extension de partage dépose pour l'app : un texte, un lien, une image, ou plusieurs.
public struct PendingImport: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public var text: String?
    public var url: String?
    /// Noms des fichiers image, à côté de la fiche, dans l'ordre : les pages d'une recette.
    public var imageFiles: [String]

    public init(id: UUID = UUID(), createdAt: Date = .now, text: String? = nil, url: String? = nil,
                imageFiles: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.url = url
        self.imageFiles = imageFiles
    }
}

/// File des partages dans le conteneur de l'App Group (ADR-017). L'extension n'ouvre jamais le
/// store : elle écrit une fiche, l'app la transforme en recette au passage au premier plan.
/// Le store garde ainsi un seul écrivain (ADR-006).
public struct PendingImportQueue: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// File dans le conteneur d'un App Group, `nil` s'il manque (installation qui le retire).
    public init?(groupContainer: URL?) {
        guard let groupContainer else { return nil }
        self.init(directory: groupContainer.appendingPathComponent("PendingImports", isDirectory: true))
    }

    @discardableResult
    public func enqueue(text: String? = nil, url: String? = nil, images: [Data] = []) throws -> PendingImport {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var item = PendingImport(text: text, url: url)
        for (index, data) in images.enumerated() {
            let name = "\(item.id.uuidString)-\(index).img"
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
            item.imageFiles.append(name)
        }
        let data = try JSONEncoder().encode(item)
        // La fiche s'écrit en dernier : l'app ne lit jamais une image à moitié copiée.
        try data.write(to: directory.appendingPathComponent("\(item.id.uuidString).json"), options: .atomic)
        return item
    }

    /// Du plus ancien au plus récent.
    public func pending() -> [PendingImport] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .compactMap { try? JSONDecoder().decode(PendingImport.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func imageURLs(of item: PendingImport) -> [URL] {
        item.imageFiles.map { directory.appendingPathComponent($0) }
    }

    public func remove(_ item: PendingImport) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent("\(item.id.uuidString).json"))
        for image in imageURLs(of: item) { try? FileManager.default.removeItem(at: image) }
    }
}
