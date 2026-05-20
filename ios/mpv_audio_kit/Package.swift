// swift-tools-version: 5.9
// libmpv ships as a dynamic xcframework downloaded from the package's
// GitHub Releases. The .binaryTarget URL + checksum pair is the SwiftPM
// equivalent of the podspec's `prepare_command` + `vendored_frameworks`.
// Run `make checksums` to refresh the checksum after a libmpv rebuild —
// the helper script updates both Package.swift and mpv_audio_kit.podspec.
import PackageDescription

let package = Package(
    name: "mpv_audio_kit",
    platforms: [
        .iOS("15.0")
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
            url: "https://github.com/ales-drnz/mpv_audio_kit/releases/download/libmpv-r7/libmpv_ios.xcframework.zip",
            checksum: "f4f04d9699bfc92b0c39884831fbbf83e93f46579a0faef8a56c356ca442e036"
        )
    ]
)
