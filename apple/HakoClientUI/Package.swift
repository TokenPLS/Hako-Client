// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HakoClientUI", platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v17)], products: [.library(name: "HakoClientUI", targets: ["HakoClientUI"])], dependencies: [.package(path: "../HakoClientKit")], targets: [.target(name: "HakoClientUI", dependencies: ["HakoClientKit"])])
