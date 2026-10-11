// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DontFool",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "DontFool", targets: ["DontFool"])],
    targets: [
        .target(name: "DontFool", path: "Sources/DontFool"),
        .testTarget(name: "DontFoolTests", dependencies: ["DontFool"],
                    path: "Tests/DontFoolTests")
    ]
)
