// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "HelloNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HelloNotch",
            path: "Sources/HelloNotch"
        ),
    ]
)
