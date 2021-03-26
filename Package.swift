// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Alley",
    platforms: [
		.iOS(.v12),
		.tvOS(.v12),
		.watchOS(.v6),
		.macOS(.v10_12)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Alley",
            targets: ["Alley"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Alley",
			dependencies: [],
            path: "Alley")
	],
	swiftLanguageVersions: [.v5]
)
