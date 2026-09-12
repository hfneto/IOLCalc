// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IOLCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IOLCore", targets: ["IOLCore"]),
    ],
    targets: [
        .target(name: "IOLCore"),
        .testTarget(
            name: "IOLCoreTests",
            dependencies: ["IOLCore"],
            resources: [.copy("Resources/golden.json"), .copy("Resources/planning.json"), .copy("Resources/toric.json")]
        ),
    ]
)
