// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SudoAdTrackerBlocker",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "SudoAdTrackerBlocker",
            targets: ["SudoAdTrackerBlocker"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sudoplatform/sudo-logging-ios", from: "2.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-config-manager-ios", from: "4.0.0"),
        .package(url: "https://github.com/sudoplatform/sudo-user-ios", from: "17.0.3"),
        .package(url: "https://github.com/aws-amplify/aws-sdk-ios-spm", exact: "2.36.7"),
    ],
    targets: [
        .target(
            name: "SudoAdTrackerBlocker",
            dependencies: [
                .product(name: "AWSCore", package: "aws-sdk-ios-spm"),
                .product(name: "AWSS3", package: "aws-sdk-ios-spm"),
                .product(name: "SudoLogging", package: "sudo-logging-ios"),
                .product(name: "SudoConfigManager", package: "sudo-config-manager-ios"),
                .product(name: "SudoUser", package: "sudo-user-ios")
            ],
            path: "SudoAdTrackerBlocker/")
    ]
)

