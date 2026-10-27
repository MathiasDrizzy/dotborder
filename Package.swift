// swift-tools-version:6.0
// dotborder: a focus border for AeroSpace windows. The logic lives in DotborderCore so it can be checked without a screen;
// `dotborder` draws it; `dotborder-tests` checks the core (`swift test` needs Xcode, this needs only the Command Line
// Tools): swift run dotborder-tests
import PackageDescription

let package = Package(
    name: "dotborder",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "dotborder", targets: ["dotborder"])],
    targets: [
        .target(name: "DotborderCore"),
        .executableTarget(name: "dotborder", dependencies: ["DotborderCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "dotborder-tests", dependencies: ["DotborderCore"]),
    ]
)
