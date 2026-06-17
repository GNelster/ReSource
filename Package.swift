// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ReSource",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ReSource",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "ReSourceTests",
            dependencies: ["ReSource"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
