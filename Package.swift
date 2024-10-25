// swift-tools-version:6.0

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
			dependencies: [],
            path: "Alley"
		),
		swiftSettings: [
			.enableExperimentalFeature("StrictConcurrency")
		]
	],
	swiftLanguageVersions: [.v6]
)
