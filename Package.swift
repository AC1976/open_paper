// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "open_paper",
    platforms: [.macOS(.v14)],
    dependencies: [
        // Full GitHub URLs so Swift Package Manager resolves cleanly on Windows
        .package(url: "https://github.com/elementary-swift/elementary.git", from: "0.7.0"),
        // YAML front matter (supports nested blocks such as `image:`)
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
        // Markdown body → HTML
        .package(url: "https://github.com/JohnSundell/Ink.git", from: "0.6.0"),
        // Web server
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        // Return Elementary HTML directly from Hummingbird routes
        .package(url: "https://github.com/hummingbird-community/hummingbird-elementary.git", from: "0.6.0"),
        // SQLite: migrations, transactions, Codable records
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        // Shared by the generator and the server: models, layout planner,
        // HTML components, styles and the upload loader.
        .target(
            name: "OpenPaperKit",
            dependencies: [
                .product(name: "Elementary", package: "elementary"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "Ink", package: "Ink"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            exclude: ["design/broadsheet.css"]
        ),
        // Static generator and `ingest` check (`swift run open_paper`).
        .executableTarget(
            name: "open_paper",
            dependencies: ["OpenPaperKit", .product(name: "Elementary", package: "elementary")]
        ),
        // Editor web server (`swift run server`).
        .executableTarget(
            name: "server",
            dependencies: [
                "OpenPaperKit",
                .product(name: "Elementary", package: "elementary"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdElementary", package: "hummingbird-elementary")
            ]
        ),
        .testTarget(
            name: "OpenPaperKitTests",
            dependencies: ["OpenPaperKit", .product(name: "GRDB", package: "GRDB.swift")]
        )
    ]
)
