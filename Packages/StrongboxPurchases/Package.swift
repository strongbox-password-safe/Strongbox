// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StrongboxPurchases",
    platforms: [
        .iOS(.v15), .macOS(.v12)
    ],
    products: [
        
        .library(
            name: "StrongboxPurchases",
            targets: ["StrongboxPurchases"]
        )
    ],
    dependencies: [
        
        .package(url: "https:
    ],
    targets: [
        
        .target(
            name: "StrongboxPurchases",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios")
            ]
        )
    ]
)
