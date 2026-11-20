// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NextUp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NextUpCore"),
        .executableTarget(
            name: "NextUp",
            dependencies: ["NextUpCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "NextUpCoreTests", dependencies: ["NextUpCore"]),
    ],
    swiftLanguageModes: [.v6]
)
