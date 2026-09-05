// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HakoClientKit", platforms: [.iOS(.v15), .macOS(.v13), .tvOS(.v17)], products: [.library(name: "HakoClientKit", targets: ["HakoClientKit"])], dependencies: [], targets: [.target(name: "HakoClientKit", dependencies: [])])
