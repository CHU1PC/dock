// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockStudio",
    platforms: [.macOS(.v15)],
    products: [.library(name: "DockStudio", targets: ["DockStudio"])],
    targets: [
        .target(name: "DockStudio", path: "DockStudio", exclude: ["DockStudioApp.swift"]),
        .testTarget(name: "DockStudioTests", dependencies: ["DockStudio"], path: "DockStudioTests")
    ],
    swiftLanguageModes: [.v5]
)
