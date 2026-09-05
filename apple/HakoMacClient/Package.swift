// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HakoMacClient", platforms: [.macOS(.v13)], products: [.library(name: "HakoMacClient", targets: ["HakoMacClient"])], dependencies: [.package(path: "../HakoClientKit"), .package(path: "../HakoClientUI")], targets: [.target(name: "HakoMacClient", dependencies: ["HakoClientKit", "HakoClientUI"], resources: [.process("Resources")])])
