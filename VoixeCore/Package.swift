// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VoixeCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "VoixeCore", targets: ["VoixeCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Clipy/Sauce", branch: "master"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.11.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.9.1"),
    ],
    targets: [
	    .target(
	        name: "VoixeCore",
	        dependencies: [
	            "Sauce",
	            .product(name: "Dependencies", package: "swift-dependencies"),
	            .product(name: "DependenciesMacros", package: "swift-dependencies"),
	            .product(name: "Logging", package: "swift-log"),
	        ],
	        path: "Sources/VoixeCore",
	        linkerSettings: [
	            .linkedFramework("IOKit")
	        ]
	    ),
        .testTarget(
            name: "VoixeCoreTests",
            dependencies: ["VoixeCore"],
            path: "Tests/VoixeCoreTests",
            resources: [
                .copy("Fixtures")
            ]
        ),
    ]
)
