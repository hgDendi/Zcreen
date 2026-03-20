// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenAnchor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ScreenAnchor",
            path: "Sources/ScreenAnchor",
            exclude: ["App/Info.plist", "App/AppIcon.icns"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/ScreenAnchor/App/Info.plist"])
            ]
        )
    ]
)
