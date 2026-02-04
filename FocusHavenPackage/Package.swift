// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FocusHavenFeature",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(
            name: "FocusHavenFeature",
            targets: ["FocusHavenFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "FocusHavenFeature",
            dependencies: [
                .product(name: "FirebaseDatabase", package: "firebase-ios-sdk")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FocusHavenFeatureTests",
            dependencies: [
                "FocusHavenFeature"
            ]
        ),
    ]
)
