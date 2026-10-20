// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UniveGame",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    dependencies: [
        // MacadeKit, the open-source game-running core of MaPC (Apache 2.0): Wine engines, bottles, stores.
        // Pinned to an exact commit so every build uses the same engine code.
        .package(url: "https://github.com/abduzeedo/mapc-engine.git", revision: "37bb046423dbb85c5cb98fee742868dccb96002d"),
    ],
    targets: [
        .executableTarget(
            name: "UniveGame",
            dependencies: [.product(name: "MacadeKit", package: "mapc-engine")],
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "UniveGameTests", dependencies: ["UniveGame"]),
    ]
)
