// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SpritzAndBlitzShared",
    products: [
        .library(name: "SpritzAndBlitzDTOs", targets: ["SpritzAndBlitzDTOs"]),
    ],
    targets: [
        .target(
            name: "SpritzAndBlitzDTOs",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
