// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MotivPlanCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CoreModels", targets: ["CoreModels"]),
        .library(name: "CoreIntents", targets: ["CoreIntents"]),
        .library(name: "SyncClient", targets: ["SyncClient"]),
    ],
    dependencies: [
        .package(path: "../TimelineEngine"),
    ],
    targets: [
        .target(name: "CoreModels", dependencies: ["TimelineEngine"]),
        .target(name: "CoreIntents", dependencies: ["CoreModels"]),
        .target(name: "SyncClient", dependencies: ["CoreModels"]),
        .testTarget(name: "CoreModelsTests", dependencies: ["CoreModels", "TimelineEngine"]),
    ]
)
