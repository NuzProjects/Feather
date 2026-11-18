// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "QuillCore", products: [.library(name: "QuillCore", targets: ["QuillCore"])], targets: [.target(name: "QuillCore", path: "Quill/Core"), .testTarget(name: "QuillCoreTests", dependencies: ["QuillCore"], path: "Tests/QuillCoreTests")])
