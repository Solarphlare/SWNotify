// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SWNotify",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SWNotify",
            targets: ["SWNotify", "CNotify"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CNotify",
            path: "Sources/cnotify",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SWNotify",
            dependencies: ["CNotify"]
        ),
        .testTarget(
            name: "SWNotifyTests",
            dependencies: ["SWNotify", "CNotify"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
