// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ClipsyKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(
            name: "ClipsyKit",
            targets: ["Store", "Capture", "Media", "Pasting", "DesignSystem", "ShelfUI", "Updates"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.12.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.10.1")
    ],
    targets: [
        .target(name: "Store", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .target(name: "Capture", dependencies: ["Store"]),
        .target(name: "Media", dependencies: ["Store"]),
        .target(name: "Pasting", dependencies: ["Store"]),
        .target(name: "DesignSystem"),
        .target(
            name: "ShelfUI",
            dependencies: [
                "DesignSystem", "Pasting", "Media", "Store",
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ]
        ),
        .target(name: "Updates", dependencies: [.product(name: "Sparkle", package: "Sparkle")]),
        .testTarget(name: "StoreTests", dependencies: ["Store"]),
        .testTarget(name: "CaptureTests", dependencies: ["Capture"]),
        .testTarget(name: "MediaTests", dependencies: ["Media"]),
        .testTarget(name: "PastingTests", dependencies: ["Pasting"]),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
        .testTarget(name: "ShelfUITests", dependencies: ["ShelfUI"]),
        .testTarget(name: "UpdatesTests", dependencies: ["Updates"])
    ]
)
