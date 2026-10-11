// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DialectBridge",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DialectBridge", targets: ["DialectBridge"])],
    targets: [
        .target(name: "DialectBridge", path: "Sources/DialectBridge"),
        .testTarget(name: "DialectBridgeTests", dependencies: ["DialectBridge"],
                    path: "Tests/DialectBridgeTests")
    ]
)
