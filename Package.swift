// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PomodoroBuddy",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PomodoroBuddy", targets: ["PomodoroBuddy"])
    ],
    targets: [
        .executableTarget(
            name: "PomodoroBuddy",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
