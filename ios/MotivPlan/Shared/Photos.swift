import PhotosUI
import SwiftUI
import UIKit

/// Photos d'un souvenir (voyage, recette), gardées sur l'iPhone seulement (ADR-016) : un dossier
/// par entrée dans l'espace de l'app. Pas de synchro pour l'instant, les photos sont lourdes.
enum PhotoStore {
    /// Côté le plus long, en points : assez pour l'écran, léger sur le disque.
    private static let maxSide: CGFloat = 1600

    static func directory(for taskId: UUID) -> URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("Photos", isDirectory: true)
            .appendingPathComponent(taskId.uuidString, isDirectory: true)
    }

    /// Dans l'ordre d'ajout.
    static func photos(of taskId: UUID) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory(for: taskId), includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func add(_ data: Data, to taskId: UUID) throws {
        guard let image = UIImage(data: data) else { return }
        let jpeg = resized(image).jpegData(compressionQuality: 0.8) ?? data
        let folder = directory(for: taskId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Horodatage en tête du nom : l'ordre alphabétique est l'ordre d'ajout.
        let name = "\(Int(Date.now.timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8)).jpg"
        try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private static func resized(_ image: UIImage) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image }
        let scale = maxSide / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Bande de photos d'une entrée, avec l'ajout depuis la photothèque. Appui long : retirer.
struct PhotoStrip: View {
    let taskId: UUID

    @State private var photos: [URL] = []
    @State private var picked: [PhotosPickerItem] = []
    @State private var viewing: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos, id: \.self) { url in
                            thumbnail(url)
                        }
                    }
                }
            }
            PhotosPicker(selection: $picked, maxSelectionCount: 10, matching: .images) {
                Label(photos.isEmpty ? "Ajouter des photos" : "Ajouter d'autres photos", systemImage: "photo.on.rectangle")
                    .pill()
            }
            .buttonStyle(.plain)
        }
        .onAppear(perform: reload)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        try? PhotoStore.add(data, to: taskId)
                    }
                }
                picked = []
                reload()
            }
        }
        .sheet(item: Binding(get: { viewing.map(PhotoURL.init) }, set: { viewing = $0?.url })) { photo in
            PhotoViewer(url: photo.url)
        }
    }

    private func thumbnail(_ url: URL) -> some View {
        Button {
            viewing = url
        } label: {
            Group {
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Palette.control
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo")
        .contextMenu {
            Button("Retirer la photo", systemImage: "trash", role: .destructive) {
                PhotoStore.remove(url)
                reload()
            }
        }
    }

    private func reload() {
        photos = PhotoStore.photos(of: taskId)
    }
}

private struct PhotoURL: Identifiable {
    let url: URL
    var id: URL { url }
}

/// Une photo en grand.
private struct PhotoViewer: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ContentUnavailableView("Photo introuvable", systemImage: "photo")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}
