// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Lume",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Lume",
            path: "Lume",
            resources: [
                .copy("Resources/Assets.xcassets"),
                .copy("Resources/Sounds/mainaudio.mp3"),
                .copy("Resources/Icone.png"),
            ]
        )
    ]
)
