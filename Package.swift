// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VibeCodingBreath",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "VibeCodingBreath", targets: ["VibeCodingBreath"])
    ],
    targets: [
        .executableTarget(
            name: "VibeCodingBreath",
            path: "Sources/VibeCodingBreath",
            resources: [.process("Resources")],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableUpcomingFeature("ConciseMagicFile"),
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]
        ),
        .testTarget(
            name: "VibeCodingBreathTests",
            dependencies: ["VibeCodingBreath"],
            path: "Tests/VibeCodingBreathTests",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=complete")
            ]
        )
    ]
)
