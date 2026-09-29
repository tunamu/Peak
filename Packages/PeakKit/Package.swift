// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "PeakKit",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "PeakCore", targets: ["PeakCore"]),
        .library(name: "PeakDesign", targets: ["PeakDesign"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PeakCore",
            dependencies: [],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .target(
            name: "PeakDesign",
            dependencies: ["PeakCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "PeakCoreTests",
            dependencies: ["PeakCore"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
        .testTarget(
            name: "PeakDesignTests",
            dependencies: ["PeakDesign"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency")
            ]
        ),
    ]
)
