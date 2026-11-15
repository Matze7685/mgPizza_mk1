// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ServerZentrale",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ServerZentrale", path: "Sources/ServerZentrale")
    ]
)
