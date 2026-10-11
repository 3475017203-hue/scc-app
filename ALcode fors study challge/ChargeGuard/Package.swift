// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ChargeGuard",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ChargeGuard", targets: ["ChargeGuard"])],
    targets: [
        .target(name: "ChargeGuard", path: "Sources/ChargeGuard"),
        .testTarget(name: "ChargeGuardTests", dependencies: ["ChargeGuard"],
                    path: "Tests/ChargeGuardTests")
    ]
)
