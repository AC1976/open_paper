// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "open_paper",
    dependencies: [
        // Full GitHub URLs so Swift Package Manager resolves cleanly on Windows
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.6.0"),
        // YAML front matter (supports nested blocks such as `image:`)
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        // Markdown body → HTML
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "open_paper",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Ink", package: "Ink")
            ]
        )
    ]
)
