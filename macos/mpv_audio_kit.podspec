#
# mpv_audio_kit macOS podspec.
#
# Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
# All rights reserved.
# Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.
#
# libmpv on macOS is distributed as a dynamic .xcframework downloaded
# from GitHub Releases as a zip. The single slice macos-<arches>/
# libmpv.framework wraps the dylib (install_name
# @rpath/libmpv.framework/libmpv); the Dart side loads it via
# DynamicLibrary.open('libmpv.framework/libmpv').
#
# A Flutter plugin ships both dependency-manager manifests — this podspec
# (CocoaPods) and Package.swift (Swift Package Manager) — and the consuming
# app's setup decides which one Flutter uses. Both describe the same
# libmpv.xcframework and share its SHA-256.
#

Pod::Spec.new do |s|
  s.name             = 'mpv_audio_kit'
  s.version          = '0.2.3'
  s.summary          = 'Flutter audio player powered by libmpv.'
  s.description      = <<-DESC
    Supports audio filters, pitch control, equalizer, and all mpv audio features.
  DESC
  s.homepage         = 'https://github.com/ales-drnz/mpv_audio_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'mpv_audio_kit' => 'ales.drnz@gmail.com' }

  s.source           = { :path => '.' }
  # Swift sources are physically under `darwin/Sources/mpv_audio_kit/`
  # and exposed in this Pod via symlinks. We can't reference them as
  # `'../darwin/...'` directly because SwiftPM (the other distribution
  # channel for this plugin) rejects `path:` values that escape the
  # package root, so the symlinks are the canonical way to keep both
  # build systems happy with one set of Swift sources.
  s.source_files     = 'mpv_audio_kit/Sources/mpv_audio_kit/**/*'

  s.dependency 'FlutterMacOS'

  # MediaPlayer is the system framework that hosts MPNowPlayingInfoCenter
  # and MPRemoteCommandCenter — the macOS lockscreen / Control Center /
  # menu-bar Now Playing entry and the play/pause/seek targets that
  # respond to Bluetooth headsets, the keyboard media keys, and Siri.
  s.frameworks = 'MediaPlayer'

  s.platform              = :osx, '12.0'
  s.swift_version         = '5.0'
  s.pod_target_xcconfig   = { 'DEFINES_MODULE' => 'YES' }

  # ── Download libmpv.xcframework from GitHub Releases ───────────────────
  # Auto-downloaded if missing or invalid. EXPECTED_SHA256 is the hash of the
  # zip archive (not the directory). The xcframework lands inside the
  # mpv_audio_kit/ SwiftPM package directory so the vendored_frameworks below
  # and Package.swift's local .binaryTarget(path:) share one location.
  s.prepare_command = <<-CMD
    RELEASE_TAG="libmpv-r7"
    EXPECTED_SHA256="20ef47b0fe5ff67ee1d86fdb0e8d6dfdb8acf50f43dd3edf9ff9f491ce7830a7"
    URL="https://github.com/ales-drnz/mpv_audio_kit/releases/download/${RELEASE_TAG}/libmpv_macos.xcframework.zip"

    mkdir -p mpv_audio_kit/Frameworks
    ZIP_FILE="mpv_audio_kit/Frameworks/libmpv_xcframework.zip"
    DOWNLOAD_NEEDED=1

    if [ -f "mpv_audio_kit/Frameworks/libmpv.xcframework/Info.plist" ] && [ -f "$ZIP_FILE" ]; then
      ACTUAL_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{ print $1 }')
      if [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ]; then
        DOWNLOAD_NEEDED=0
      else
        echo "SHA-256 mismatch! Expected $EXPECTED_SHA256 but got $ACTUAL_SHA256. Redownloading..."
        rm -rf "mpv_audio_kit/Frameworks/libmpv.xcframework"
        rm -f "$ZIP_FILE"
      fi
    elif [ -d "mpv_audio_kit/Frameworks/libmpv.xcframework" ] && [ ! -f "$ZIP_FILE" ]; then
      # Vendored xcframework already in place (dev workflow / make checksums);
      # no download needed regardless of EXPECTED_SHA256.
      DOWNLOAD_NEEDED=0
    fi

    if [ $DOWNLOAD_NEEDED -eq 1 ]; then
      echo "Downloading libmpv_macos.xcframework.zip from $URL..."
      curl -L -o "$ZIP_FILE" "$URL"

      ACTUAL_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{ print $1 }')
      if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "ERROR: SHA-256 verification failed for downloaded file!"
        rm -f "$ZIP_FILE"
        exit 1
      fi

      unzip -o "$ZIP_FILE" -d mpv_audio_kit/Frameworks/
      rm -f "$ZIP_FILE"
    fi
  CMD

  # vendored_frameworks gets the .xcframework auto-embedded into the host
  # app's Contents/Frameworks/ and codesigned — no script_phase needed
  # (unlike a bare .dylib, which CocoaPods does not embed).
  s.vendored_frameworks = 'mpv_audio_kit/Frameworks/libmpv.xcframework'
end
