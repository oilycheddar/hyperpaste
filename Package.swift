// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HyperPaste",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "HyperPaste",
            path: "Sources/HyperPaste"
        )
    ]
)
