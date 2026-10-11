// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SafeHarvest",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SafeHarvest", targets: ["SafeHarvest"])],
    targets: [
        .target(name: "SafeHarvest", path: "Sources/SafeHarvest"),
        .testTarget(name: "SafeHarvestTests", dependencies: ["SafeHarvest"],
                    path: "Tests/SafeHarvestTests")
    ]
)
