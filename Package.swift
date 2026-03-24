// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Zcreen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Zcreen",
            path: "Sources/Zcreen",
            exclude: ["App/Info.plist", "App/AppIcon.icns"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate",
                              "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist",
                              "-Xlinker", "Sources/Zcreen/App/Info.plist"])
            ]
        ),
        .testTarget(
            name: "ZcreenTests",
            dependencies: ["Zcreen"],
            path: "Tests/ZcreenTests"
        )
    ]
)
