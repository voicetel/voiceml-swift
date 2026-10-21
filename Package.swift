// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoiceML",
    // SDK release version: 0.9.4 (see Sources/VoiceML/Version.swift).
    // Tools 6.0 builds the package in the Swift 6 language mode (strict
    // concurrency) while keeping the iOS 15 / macOS 12 platform floor.
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [.library(name: "VoiceML", targets: ["VoiceML"])],
    dependencies: [],
    targets: [
        .target(name: "VoiceML", path: "Sources/VoiceML"),
        .testTarget(name: "VoiceMLTests", dependencies: ["VoiceML"], path: "Tests/VoiceMLTests", exclude: ["Fixtures"]),
    ]
)
