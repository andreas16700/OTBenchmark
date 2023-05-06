// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OTBenchmark",
	platforms: [
		.macOS(.v13)
	],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
		.executable(name: "otBench", targets: ["OTBenchmark"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
		.package(url: "https://github.com/andreas16700/MockShopifyClient", branch: "main"),
		.package(url: "https://github.com/andreas16700/MockPowersoftClient", branch: "main"),
		.package(url: "https://github.com/andreas16700/OTModelSyncer_pub", branch: "main"),
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
		.package(url: "https://github.com/apple/swift-nio.git", from: "2.51.1"),
		.package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.24.0"),
		.package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.26.0"),
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.17.0"),
		.package(url: "https://github.com/andreas16700/RateLimitingCommunicator", branch: "main")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
		.executableTarget(name: "OTBenchmark", dependencies: [
			"MockShopifyClient"
			,"MockPowersoftClient"
			,.product(name: "OTModelSyncer", package: "OTModelSyncer_pub")
			,.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "NIOSSL", package: "swift-nio-ssl"),
				.product(name: "NIOHTTP2", package: "swift-nio-http2"),
				.product(name: "AsyncHTTPClient", package: "async-http-client"),
			.product(name: "RateLimitingCommunicator", package: "RateLimitingCommunicator")
		]),
        .testTarget(
            name: "OTBenchmarkTests",
            dependencies: ["OTBenchmark"]),
    ]
)
