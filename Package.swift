// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReviewBar",
    platforms: [.macOS(.v26)],   // Liquid Glass(.buttonStyle(.glass))·onGeometryChange 등. SDK 26.5
    targets: [
        .executableTarget(
            name: "ReviewBar",
            path: "Sources/ReviewBar",
            resources: [.process("Resources")],   // github-mark.png → Bundle.module
            // 엄격 동시성 경고를 줄여 로컬 MVP 빌드를 단순화(추후 .v6로 상향 가능)
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
