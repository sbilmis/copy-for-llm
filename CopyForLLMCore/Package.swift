// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CopyForLLMCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CopyForLLMCore", targets: ["CopyForLLMCore"]),
        .executable(name: "llmcopy", targets: ["llmcopy-cli"]),
    ],
    targets: [
        .target(name: "CopyForLLMCore"),
        .executableTarget(name: "llmcopy-cli", dependencies: ["CopyForLLMCore"]),
        .testTarget(name: "CopyForLLMCoreTests", dependencies: ["CopyForLLMCore"]),
    ]
)
