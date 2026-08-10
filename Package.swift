// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Quicksilver",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "QuicksilverCore", targets: ["Core", "Memory", "Personas", "ServicesAI", "Nexus"]),
        .library(name: "QuicksilverIntents", targets: ["QuicksilverIntents"]),
    ],
    dependencies: [
        // Official Sentry Cocoa SDK (compile-from-source product recommended)
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.25.0")
    ],
    targets: [
        .target(name: "Core", path: "Core"),
        .target(
            name: "Memory",
            dependencies: ["Core"],
            path: "Memory"
        ),
        .target(name: "Personas", dependencies: ["Core"], path: "Personas"),
        .target(name: "ServicesAI", dependencies: ["Core"], path: "Services/AI"),
        .target(
            name: "Nexus",
            dependencies: ["Core"],
            path: "Nexus",
            exclude: ["PIPELINE.md"]
        ),
        .target(
            name: "QuicksilverIntents",
            dependencies: ["Core", "Personas", "Nexus", "Memory", "ServicesAI"],
            path: "Intents"
        ),
        .testTarget(
            name: "QuicksilverCoreTests",
            dependencies: ["Core", "Memory", "Personas", "ServicesAI", "Nexus", "QuicksilverIntents"],
            path: "Tests"
        ),
    ]
)
