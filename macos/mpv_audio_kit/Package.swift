// swift-tools-version: 5.9
// libmpv ships as a dynamic xcframework downloaded from the package's
// GitHub Releases (same shape as iOS). The .binaryTarget URL + checksum
// pair is the SwiftPM equivalent of the podspec's `prepare_command` +
// `vendored_frameworks`. Run `make checksums` to refresh the checksum
// after a libmpv rebuild — the helper script updates both Package.swift
// and mpv_audio_kit.podspec.
import PackageDescription

let package = Package(
    name: "mpv_audio_kit",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "mpv-audio-kit", targets: ["mpv_audio_kit"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "mpv_audio_kit",
            dependencies: ["libmpv"],
            path: "Sources/mpv_audio_kit"
        ),
        .binaryTarget(
            name: "libmpv",
            url: "https://github.com/ales-drnz/mpv_audio_kit/releases/download/libmpv-r7/libmpv_macos.xcframework.zip",
            checksum: "67fae1f39876102ad19a4bf24b316b1ade489f0ac1e9eef85fa39a170858c76d"
        )
    ]
)
