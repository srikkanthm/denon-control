// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DenonVol",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DenonVol",
            path: "Sources/DenonVol"
        )
    ]
)