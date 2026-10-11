// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LiftTogether",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "LiftTogether", targets: ["LiftTogether"])],
    targets: [
        .target(name: "LiftTogether", path: "Sources/LiftTogether"),
        .testTarget(name: "LiftTogetherTests", dependencies: ["LiftTogether"],
                    path: "Tests/LiftTogetherTests")
    ]
)
