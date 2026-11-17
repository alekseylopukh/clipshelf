// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClipsyKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ClipsyKit", targets: ["Store", "Capture", "Media", "Pasting", "DesignSystem", "ShelfUI"])
    ],
    targets: [
        .target(name: "Store"),
        .target(name: "Capture", dependencies: ["Store"]),
        .target(name: "Media"),
        .target(name: "Pasting", dependencies: ["Store"]),
        .target(name: "DesignSystem"),
        .target(name: "ShelfUI", dependencies: ["DesignSystem", "Pasting", "Media", "Store"]),
        .testTarget(name: "StoreTests", dependencies: ["Store"]),
        .testTarget(name: "CaptureTests", dependencies: ["Capture"]),
        .testTarget(name: "MediaTests", dependencies: ["Media"]),
        .testTarget(name: "PastingTests", dependencies: ["Pasting"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "ShelfUITests", dependencies: ["ShelfUI"])
    ]
)
