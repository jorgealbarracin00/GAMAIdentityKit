// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GAMAIdentityKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "GAMAIdentityKit", targets: ["GAMAIdentityKit"])
    ],
    targets: [
        .target(name: "GAMAIdentityKit"),
        .testTarget(name: "GAMAIdentityKitTests", dependencies: ["GAMAIdentityKit"])
    ],
    swiftLanguageModes: [.v6]
)
