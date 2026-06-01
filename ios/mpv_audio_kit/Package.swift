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
        .iOS("15.0")
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
            // required for App Store submission. Unlike the Swift sources,
            // this is a real per-platform file (NOT a symlink into darwin/):
            // SwiftPM does not dereference a symlinked resource during the
            // copy phase, so a symlink here fails the build with "no such
            // file". Keep the iOS/macOS copies in sync by hand. .process
            // places it at the bundle root.
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ],
            linkerSettings: [
                // MediaPlayer hosts MPNowPlayingInfoCenter +
                // MPRemoteCommandCenter (lockscreen / Control Center
                // Now Playing entry). AVFoundation is needed for
                // AVAudioSession (interruption handling).
                .linkedFramework("MediaPlayer"),
                .linkedFramework("AVFoundation"),
            ]
        ),
        .binaryTarget(
            name: "libmpv",
        //  path: "Frameworks/libmpv.xcframework"),
            url: "https://github.com/ales-drnz/mpv_audio_kit/releases/download/libmpv-r7/libmpv_ios.xcframework.zip",
            checksum: "8500923392ee5ae5d4e3263e12a68e29aa805596b85d56a9a26f2239c91173e0"),
    ]
)
