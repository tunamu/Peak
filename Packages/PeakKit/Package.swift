// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "PeakKit",
    platforms: [
        .iOS(.v26),
        // Only so `swift test` can build the SwiftUI code on a Mac host; the app ships on iOS.
        .macOS(.v26),
    ],
    products: [
        .library(name: "PeakCore", targets: ["PeakCore"]),
        .library(name: "PeakDesign", targets: ["PeakDesign"]),
    ],
    dependencies: [
        // Reads .xlsx files (a ZIP of XML) for import. 0.x: minor versions may break, so they are taken by hand.
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMinor(from: "0.9.20"))
    ],
    targets: [
        .target(
            name: "PeakCore",
            dependencies: [.product(name: "ZIPFoundation", package: "ZIPFoundation")],
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
            dependencies: ["PeakCore", .product(name: "ZIPFoundation", package: "ZIPFoundation")],
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
