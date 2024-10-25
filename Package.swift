// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Alley",
    platforms: [
		.iOS(.v15),
		.tvOS(.v15),
		.watchOS(.v10),
		.macOS(.v12),
		.visionOS(.v1)
    ],
    products: [
        .library(
            name: "Alley",
            targets: ["Alley"]
		),
    ],
    targets: [
        .target(
            name: "Alley",
			swiftSettings: [
				.enableExperimentalFeature("StrictConcurrency")
			]
		)
	],
	swiftLanguageModes: [.v6]
)
