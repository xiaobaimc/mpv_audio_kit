#
# mpv_audio_kit macOS podspec
#
# libmpv on macOS is distributed as a dynamic xcframework downloaded from
# GitHub Releases (same shape as iOS). The single slice wraps a Universal
# (arm64 + x86_64) Mach-O dylib (install_name `@rpath/libmpv.framework/libmpv`);
# the Dart side loads it via `DynamicLibrary.open('libmpv.framework/libmpv')`.
#

Pod::Spec.new do |s|
  s.name             = 'mpv_audio_kit'
  s.version          = '0.2.0'
  s.summary          = 'Flutter audio player powered by libmpv.'
  s.description      = <<-DESC
    Supports audio filters, pitch control, equalizer, and all mpv audio features.
  DESC
  s.homepage         = 'https://github.com/ales-drnz/mpv_audio_kit'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'mpv_audio_kit' => 'ales-drnz.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'mpv_audio_kit/Sources/mpv_audio_kit/**/*'

  s.dependency 'FlutterMacOS'

  s.platform    = :osx, '12.0'
  s.swift_version = '5.0'

  # ── Dynamic libmpv XCFramework ────────────────────────────────────────────
  # Automatically downloaded from GitHub Releases if missing or invalid.
  # Run `make checksums` to refresh the SHA-256 after a libmpv rebuild —
  # the helper script updates both this file and Package.swift.
  s.prepare_command = <<-CMD
    MPV_RELEASE_VERSION="libmpv-r7"
    EXPECTED_SHA256="67fae1f39876102ad19a4bf24b316b1ade489f0ac1e9eef85fa39a170858c76d"
    URL="https://github.com/ales-drnz/mpv_audio_kit/releases/download/${MPV_RELEASE_VERSION}/libmpv_macos.xcframework.zip"

    mkdir -p Frameworks
    ZIP_FILE="Frameworks/libmpv_xcframework.zip"
    DOWNLOAD_NEEDED=1

    if [ -f "Frameworks/libmpv.xcframework/Info.plist" ] && [ -f "$ZIP_FILE" ]; then
      ACTUAL_SHA256=$(shasum -a 256 "$ZIP_FILE" | awk '{ print $1 }')
      if [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ]; then
        DOWNLOAD_NEEDED=0
      else
        echo "SHA-256 mismatch! Expected $EXPECTED_SHA256 but got $ACTUAL_SHA256. Redownloading..."
        rm -rf "Frameworks/libmpv.xcframework"
        rm -f "$ZIP_FILE"
      fi
    elif [ -d "Frameworks/libmpv.xcframework" ] && [ ! -f "$ZIP_FILE" ]; then
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

      unzip -o "$ZIP_FILE" -d Frameworks/
      rm -f "$ZIP_FILE"
    fi
  CMD

  s.vendored_frameworks = 'Frameworks/libmpv.xcframework'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE'  => 'YES',
  }
end
