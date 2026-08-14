// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BrewManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BrewManager", targets: ["BrewManager"])
    ],
    targets: [
        .executableTarget(
            name: "BrewManager"
        ),
        .testTarget(
            name: "BrewManagerTests",
            dependencies: ["BrewManager"]
        )
    ]
)
