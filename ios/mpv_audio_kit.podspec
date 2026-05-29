#
# mpv_audio_kit iOS podspec
#
# libmpv on iOS is distributed as a dynamic xcframework downloaded from
# GitHub Releases. Each slice wraps a Mach-O dylib (install_name
# `@rpath/libmpv.framework/libmpv`); the Dart side loads it via
# `DynamicLibrary.open('libmpv.framework/libmpv')`. The xcframework includes:
#   ios-arm64                    – device (arm64)
#   ios-arm64_x86_64-simulator   – simulator (arm64 + x86_64 lipo'd)
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
  s.author           = { 'mpv_audio_kit' => 'ales-drnz.com' }
  s.source           = { :path => '.' }
  # Swift sources are physically under `darwin/Sources/mpv_audio_kit/`
  # and exposed in this Pod via symlinks. We can't reference them as
  # `'../darwin/...'` directly because SwiftPM (the other distribution
  # channel for this plugin) rejects `path:` values that escape the
  # package root, so the symlinks are the canonical way to keep both
  # build systems happy with one set of Swift sources.
  s.source_files     = 'mpv_audio_kit/Sources/mpv_audio_kit/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  # Required frameworks. MediaPlayer hosts MPNowPlayingInfoCenter +
  # MPRemoteCommandCenter for the lockscreen / Control Center / CarPlay
  # Now Playing entry. AVFoundation is needed for AVAudioSession (audio
  # interruption handling).
  s.frameworks = 'MediaPlayer', 'AVFoundation', 'AudioToolbox', 'Security', 'CoreFoundation'

  # ── Dynamic libmpv XCFramework ────────────────────────────────────────────
  # Automatically downloaded from GitHub Releases if missing or invalid.
  # Run `make checksums` to refresh the SHA-256 after a libmpv rebuild —
  # the helper script updates both this file and Package.swift.
  s.prepare_command = <<-CMD
    MPV_RELEASE_VERSION="libmpv-r7"
    EXPECTED_SHA256="8500923392ee5ae5d4e3263e12a68e29aa805596b85d56a9a26f2239c91173e0"
    URL="https://github.com/ales-drnz/mpv_audio_kit/releases/download/${MPV_RELEASE_VERSION}/libmpv_ios.xcframework.zip"

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
      DOWNLOAD_NEEDED=0
    fi

    if [ $DOWNLOAD_NEEDED -eq 1 ]; then
      echo "Downloading libmpv_ios.xcframework.zip from $URL..."
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

  s.vendored_frameworks = 'mpv_audio_kit/Frameworks/libmpv.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'  => 'YES',
    'ENABLE_BITCODE'  => 'NO',
  }
  s.swift_version = '5.0'
end
