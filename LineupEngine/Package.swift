// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LineupEngine",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "LineupEngine", targets: ["LineupEngine"]),
        .executable(name: "lineup-cli", targets: ["lineup-cli"]),
    ],
    targets: [
        .target(
            name: "LineupEngine",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "lineup-cli",
            dependencies: ["LineupEngine"]
        ),
        .testTarget(
            name: "LineupEngineTests",
            dependencies: ["LineupEngine"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
