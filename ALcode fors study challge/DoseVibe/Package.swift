// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DoseVibe",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DoseVibe", targets: ["DoseVibe"])],
    targets: [
        .target(name: "DoseVibe", path: "Sources/DoseVibe"),
        .testTarget(name: "DoseVibeTests", dependencies: ["DoseVibe"],
                    path: "Tests/DoseVibeTests")
    ]
)
