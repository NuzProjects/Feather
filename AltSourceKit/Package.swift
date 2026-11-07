// swift-tools-version: 5.8

import PackageDescription

let package = Package(
	name: "AltSourceKit",
	platforms: [
		.iOS(.v14),
		.tvOS(.v14),
		.custom("xros", versionString: "1.3")
	],
	products: [
		.library(
			name: "AltSourceKit",
			targets: ["AltSourceKit"]),
	],
	targets: [
		.target(
			name: "AltSourceKit"),

	]
)
