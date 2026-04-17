// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperPaste",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "HyperPaste",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/HyperPaste"
        )
    ]
)
