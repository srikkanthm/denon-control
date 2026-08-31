// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DenonControl",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DenonControl",
            path: "Sources/DenonControl"
        )
    ]
)