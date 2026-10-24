// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UniveGame",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    dependencies: [
        // UniveEngine (Apache 2.0): Wine engines, environments, graphics backends and store integrations.
        // Derived from MacadeKit (Apache 2.0); pinned to an exact commit so every build uses the same engine code.
        .package(url: "https://github.com/MuratDugan/UniveEngine.git", revision: "dc23c6cf1d74792e57d0a43e07ad8eb5b44948c6"),
    ],
    targets: [
        .executableTarget(
            name: "UniveGame",
            dependencies: [.product(name: "UniveEngineKit", package: "UniveEngine")],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "UniveGameTests", dependencies: ["UniveGame"]),
    ]
)
