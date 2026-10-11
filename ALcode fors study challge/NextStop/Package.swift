// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NextStop",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NextStop", targets: ["NextStop"])],
    targets: [
        .target(name: "NextStop", path: "Sources/NextStop"),
        .testTarget(name: "NextStopTests", dependencies: ["NextStop"],
                    path: "Tests/NextStopTests")
    ]
)
