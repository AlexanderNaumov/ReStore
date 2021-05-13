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
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "6.1.0")
    ],
    targets: [
        .target(name: "ReStore", dependencies: ["RxSwift", .product(name: "RxRelay", package: "RxSwift")], path: "Sources")
    ]
)
