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
    dependencies: [
        .package(url: "https://github.com/AlexanderNaumov/When.git", .branch("master")),
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "5.0.0")
    ],
    targets: [
        .target(name: "ReStore", dependencies: ["When", .product(name: "RxSwift", package: "RxSwift")], path: "Sources")
    ]
)
