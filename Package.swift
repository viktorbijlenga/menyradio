// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Menyradio",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Menyradio", targets: ["Menyradio"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .executableTarget(
            name: "Menyradio",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "MenyradioTests", dependencies: ["Menyradio"], resources: [.copy("Fixtures")])
    ]
)
