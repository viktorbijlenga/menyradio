// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "Menyradio", platforms: [.macOS(.v14)], products: [.executable(name: "Menyradio", targets: ["Menyradio"])], targets: [.executableTarget(name: "Menyradio"), .testTarget(name: "MenyradioTests", dependencies: ["Menyradio"], resources: [.copy("Fixtures")])])
