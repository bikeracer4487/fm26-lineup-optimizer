// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LineupApp",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "LineupApp", targets: ["LineupApp"]),
    ],
    dependencies: [
        .package(path: "../LineupEngine"),
    ],
    targets: [
        .target(
            name: "LineupAppCore",
            dependencies: [.product(name: "LineupEngine", package: "LineupEngine")]
        ),
        .target(
            name: "LineupAppUI",
            dependencies: ["LineupAppCore", .product(name: "LineupEngine", package: "LineupEngine")]
        ),
        .executableTarget(
            name: "LineupApp",
            dependencies: ["LineupAppCore", "LineupAppUI", .product(name: "LineupEngine", package: "LineupEngine")]
        ),
        .testTarget(
            name: "LineupAppCoreTests",
            dependencies: ["LineupAppCore"]
        ),
    ]
)
