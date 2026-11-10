// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WildernessCore",
    platforms: [.macOS(.v14), .tvOS(.v17), .iOS(.v17)],
    products: [
        .library(name: "WildernessCore", targets: ["WildernessCore"]),
    ],
    targets: [
        .target(name: "WildernessCore"),
        .testTarget(name: "WildernessCoreTests", dependencies: ["WildernessCore"]),
    ]
)
