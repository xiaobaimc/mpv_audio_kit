// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:io';

/// Configures the bulk waveform analyzer.
///
/// The analyzer runs in libmpv on a worker thread spawned at file load
/// and emits its results via [PlayerStream.waveform]. Disabled by
/// default — opt in with [WaveformSettings.enabled] = `true`.
///
/// When [cacheDirectory] is provided, the pipeline writes the computed
/// envelope to a sidecar file there (keyed by file path + mtime +
/// size). Subsequent loads of the same file hit the cache and emit
/// the envelope synchronously, skipping the decoder entirely.
///
/// Apply via [Player.setWaveform] at any time. The new policy applies
/// from the next track-load onward; the current track's envelope is
/// retained until the next reset.
final class WaveformSettings {
  /// Whether the analyzer runs at all. `false` (default) → no decode
  /// work is scheduled, the waveform stream stays at `null`, and no
  /// cache I/O happens.
  final bool enabled;

  /// Directory where computed envelopes are cached for instant reuse
  /// on subsequent loads. `null` → no persistent cache (every load
  /// re-runs the analyzer, but in-memory state still survives within
  /// the same track).
  final Directory? cacheDirectory;

  /// Soft cap on the cache directory's total size in bytes. When a
  /// new write would push past this, the oldest entries (by mtime)
  /// are deleted until it fits. `null` (default) → no size-based
  /// eviction; the cache grows as long as new tracks are loaded.
  final int? maxCacheBytes;

  const WaveformSettings({
    this.enabled = false,
    this.cacheDirectory,
    this.maxCacheBytes,
  });

  /// Convenience constant — analyzer off, no cache. Default for
  /// [PlayerConfiguration.waveform].
  static const WaveformSettings disabled = WaveformSettings();

  WaveformSettings copyWith({
    bool? enabled,
    Directory? cacheDirectory,
    int? maxCacheBytes,
  }) =>
      WaveformSettings(
        enabled: enabled ?? this.enabled,
        cacheDirectory: cacheDirectory ?? this.cacheDirectory,
        maxCacheBytes: maxCacheBytes ?? this.maxCacheBytes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaveformSettings &&
          other.enabled == enabled &&
          other.cacheDirectory?.path == cacheDirectory?.path &&
          other.maxCacheBytes == maxCacheBytes);

  @override
  int get hashCode =>
      Object.hash(enabled, cacheDirectory?.path, maxCacheBytes);

  @override
  String toString() =>
      'WaveformSettings(enabled: $enabled, '
      'cacheDirectory: ${cacheDirectory?.path}, '
      'maxCacheBytes: $maxCacheBytes)';
}
