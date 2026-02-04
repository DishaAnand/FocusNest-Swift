// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FocusNestFeature",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(
            name: "FocusNestFeature",
            targets: ["FocusNestFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "FocusNestFeature",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FocusNestFeatureTests",
            dependencies: [
                "FocusNestFeature"
            ]
        ),
    ]
)
