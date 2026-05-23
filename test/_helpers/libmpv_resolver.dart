// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:io';

/// Resolves the bundled libmpv path for the current host so the runtime
/// test files don't need to repeat the platform branching.
///
/// The bundled binary lives under the repo root at:
///   - macOS  → `macos/mpv_audio_kit/Frameworks/libmpv.xcframework/macos-arm64_x86_64/libmpv.framework/libmpv`
///   - Linux  → `linux/libs/<arch>/libmpv.so`        (`<arch>`: `x86_64` | `aarch64`)
///   - Windows → `windows/libs/<arch>/libmpv.dll`    (`<arch>`: `x86_64` | `arm64`)
///
/// The host arch is derived from `Abi.current()`. Returns `null` on
/// platforms without a pre-built binary (Android, iOS) or when the file
/// is missing — call sites use it to mark the test group as skipped
/// instead of failing.
String? resolveLibmpv() {
  final root = Directory.current.path;
  if (Platform.isMacOS) {
    // SwiftPM moved the xcframework one level deeper into the plugin
    // module directory (`macos/mpv_audio_kit/Frameworks/…`). Keep the
    // pre-SwiftPM path as a fallback so older test checkouts still
    // resolve.
    const tail = 'libmpv.xcframework/macos-arm64_x86_64/'
        'libmpv.framework/libmpv';
    for (final p in [
      '$root/macos/mpv_audio_kit/Frameworks/$tail',
      '$root/macos/Frameworks/$tail',
    ]) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }
  if (Platform.isLinux) {
    final arch = switch (Abi.current()) {
      Abi.linuxArm64 => 'aarch64',
      Abi.linuxX64 => 'x86_64',
      _ => null,
    };
    if (arch == null) return null;
    final p = '$root/linux/libs/$arch/libmpv.so';
    return File(p).existsSync() ? p : null;
  }
  if (Platform.isWindows) {
    final arch = switch (Abi.current()) {
      Abi.windowsArm64 => 'arm64',
      Abi.windowsX64 => 'x86_64',
      _ => null,
    };
    if (arch == null) return null;
    final p = '$root\\windows\\libs\\$arch\\libmpv.dll';
    return File(p).existsSync() ? p : null;
  }
  return null;
}
