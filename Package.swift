// swift-tools-version: 6.0
// Author: Thawee.p <thaweemail@gmail.com>

import PackageDescription

let package = Package(
    name: "StatusDashboard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StatusDashboard", targets: ["StatusDashboard"])
    ],
    targets: [
        .executableTarget(
            name: "StatusDashboard",
            dependencies: [],
            path: "Sources/StatusDashboard"
        )
    ]
)
