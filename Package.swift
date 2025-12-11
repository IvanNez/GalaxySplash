// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GalaxySplash",
    platforms: [.iOS(.v15), .macOS(.v12), .watchOS(.v8), .tvOS(.v15)],
    products: [
        .library(name: "GalaxySplash", targets: ["GalaxySplash"]),
    ],
    dependencies: [
        .package(url: "https://github.com/OneSignal/OneSignal-iOS-SDK", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "GalaxySplash",
            dependencies: [
                .product(name: "OneSignalFramework", package: "OneSignal-iOS-SDK")
            ]
        ),
        .testTarget(
            name: "GalaxySplashTests",
            dependencies: ["GalaxySplash"]
        ),
    ]
)
