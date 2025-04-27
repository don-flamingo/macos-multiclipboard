// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v11)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.1.3")
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            dependencies: ["HotKey"],
            path: ".",
            exclude: ["ClipboardManager.swift", "README.md", "build_app.sh", "ClipboardManager.app"]
        )
    ]
) 