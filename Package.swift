// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "FeatherCore", products: [.library(name: "FeatherCore", targets: ["FeatherCore"])], targets: [.target(name: "FeatherCore", path: "Feather/Core"), .testTarget(name: "FeatherCoreTests", dependencies: ["FeatherCore"], path: "Tests/FeatherCoreTests")])
