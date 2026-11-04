// swift-tools-version: 6.0
// Import dans la Mémoire (lot 15, ADR-017) : découpage d'une recette, page web d'une recette,
// fiches TMDB, file des partages. Foundation seule, testable sous Windows et Linux.
import PackageDescription

let package = Package(
    name: "MemoryImport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MemoryImport", targets: ["MemoryImport"]),
    ],
    targets: [
        .target(name: "MemoryImport"),
        .testTarget(name: "MemoryImportTests", dependencies: ["MemoryImport"]),
    ]
)
