// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "SpritzAndBlitzServer",
    platforms: [
       .macOS("26.2")
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "5.0.0-beta.4"),
        // 📝 Logging in Vapor
        .package(url: "https://github.com/vapor/console-kit.git", from: "5.0.0-beta"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent-kit.git", from: "1.56.0"),
        // 🐘 Fluent driver for Postgres.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "SpritzAndBlitzServer",
            dependencies: [
                .product(name: "FluentKit", package: "fluent-kit"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "ConsoleLogger", package: "console-kit"),
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "SpritzAndBlitzServerTests",
            dependencies: [
                .target(name: "SpritzAndBlitzServer"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]
}
