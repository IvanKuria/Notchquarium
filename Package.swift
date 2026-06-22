// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchquarium",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Notchquarium",
            path: "Sources/Notchquarium"
        ),
        .testTarget(
            name: "NotchquariumTests",
            dependencies: ["Notchquarium"],
            path: "Tests/NotchquariumTests"
        ),
    ]
)
