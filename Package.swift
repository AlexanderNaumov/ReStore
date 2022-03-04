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
        .package(url: "https://github.com/ReactiveX/RxSwift", from: "6.1.0"),
        .package(url: "https://github.com/vadymmarkov/When", .branch("master"))
    ],
    targets: [
        .target(name: "ReStore", dependencies: ["RxSwift"], path: "Sources")
    ]
)
