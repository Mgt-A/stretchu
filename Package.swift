// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stretchu",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Stretchu",
            path: "Sources/Stretchu",
            resources: [.process("Localization")]
        ),
        .testTarget(
            name: "StretchuTests",
            dependencies: ["Stretchu"],
            path: "Tests/StretchuTests"
        ),
    ]
)
