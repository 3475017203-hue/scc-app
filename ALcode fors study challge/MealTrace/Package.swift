// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MealTrace",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "MealTrace", targets: ["MealTrace"])],
    targets: [
        .target(name: "MealTrace", path: "Sources/MealTrace"),
        .testTarget(name: "MealTraceTests", dependencies: ["MealTrace"],
                    path: "Tests/MealTraceTests")
    ]
)
