// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "ReStore",
    platforms: [
        .iOS(.v10)
    ],
    products: [
        .library(name: "ReStore", targets: ["ReStore"])
    ],
    targets: [
        .target(name: "ReStore", dependencies: [], path: "Sources")
    ]
)
