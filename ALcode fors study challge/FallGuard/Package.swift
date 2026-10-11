// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FallGuard",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FallGuard", targets: ["FallGuard"])],
    targets: [
        .target(name: "FallGuard", path: "Sources/FallGuard"),
        .testTarget(name: "FallGuardTests", dependencies: ["FallGuard"],
                    path: "Tests/FallGuardTests")
    ]
)
