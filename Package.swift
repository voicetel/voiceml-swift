// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceML",
    // SDK release version: 0.9.1 (see Sources/VoiceML/Version.swift)
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15), .watchOS(.v8)],
    products: [.library(name: "VoiceML", targets: ["VoiceML"])],
    dependencies: [],
    targets: [
        .target(name: "VoiceML", path: "Sources/VoiceML"),
        .testTarget(name: "VoiceMLTests", dependencies: ["VoiceML"], path: "Tests/VoiceMLTests"),
    ]
)
