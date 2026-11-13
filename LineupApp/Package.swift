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
            dependencies: ["LineupAppCore", .product(name: "LineupEngine", package: "LineupEngine")],
            // Bricolage Grotesque and Figtree with their licences, registered when the app starts,
            // and the app's icon (built by tools/make_app_icon.sh from LineupApp/Icon).
            resources: [.copy("Resources/Fonts"), .copy("Resources/AppIcon.icns")]
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
