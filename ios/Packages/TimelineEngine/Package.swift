// swift-tools-version: 6.0
// Moteur de timeline : Foundation seule, aucun framework Apple, testable sous Windows.
import PackageDescription

let package = Package(
    name: "TimelineEngine",
    products: [
        .library(name: "TimelineEngine", targets: ["TimelineEngine"]),
    ],
    targets: [
        .target(name: "TimelineEngine"),
        .testTarget(name: "TimelineEngineTests", dependencies: ["TimelineEngine"]),
    ]
)
