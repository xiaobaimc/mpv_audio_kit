// swift-tools-version: 5.9
// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
//
// libmpv ships as a dynamic .xcframework, consumed via a SwiftPM
// .binaryTarget. Two interchangeable forms — keep exactly ONE active:
//
//   • url + checksum — downloads the xcframework from this package's
//     GitHub Releases. The standard practice for a distributed binary;
//     use this once the release zip is published.
//   • path — uses a libmpv.xcframework already in Frameworks/. Use
//     this to test a local libmpv build before publishing a release.

import PackageDescription

let package = Package(
    name: "mpv_audio_kit",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "mpv-audio-kit", targets: ["mpv_audio_kit"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "mpv_audio_kit",
            dependencies: [
                "libmpv",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            // Swift sources are physically under `darwin/Sources/mpv_audio_kit/`
            // and exposed here via symlinks. SwiftPM rejects `path:`
            // values that escape the package root (`outside the package
            // root` error), so the symlinks are the canonical way to
            // expose the shared darwin/ tree to both iOS and macOS
            // SwiftPM packages without duplicating the Swift code.
            path: "Sources/mpv_audio_kit",
            // Apple privacy manifest, embedded into the built bundle —
            // required for App Store submission. Same shared darwin/ file the
            // Swift sources symlink to; .process places it at the bundle root.
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            linkerSettings: [
                // MediaPlayer hosts MPNowPlayingInfoCenter +
                // MPRemoteCommandCenter for the lockscreen / Control
                // Center Now Playing entry.
                .linkedFramework("MediaPlayer"),
            ]
        ),
        .binaryTarget(
            name: "libmpv",
        //  path: "Frameworks/libmpv.xcframework"),
            url: "https://github.com/ales-drnz/mpv_audio_kit/releases/download/libmpv-r7/libmpv_macos.xcframework.zip",
            checksum: "20ef47b0fe5ff67ee1d86fdb0e8d6dfdb8acf50f43dd3edf9ff9f491ce7830a7"),
    ]
)
