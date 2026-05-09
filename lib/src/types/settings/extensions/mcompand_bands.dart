// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One band of the lavfi `mcompand` filter — a self-contained
/// compander stage with its own dynamics envelope, transfer
/// function, soft-knee, makeup gain, and crossover frequency.
///
/// `mcompand` itself splits the input into N bands at the crossover
/// frequencies (lows .. highs in ascending order), runs each band
/// through its own [McompandBand], then sums them back. The band
/// model carries the same six parameters as
/// [AcompressorSettings] — threshold, ratio, attack, release, knee,
/// makeup — plus the band's upper-edge crossover, which lavfi reads
/// as the boundary between this band and the next.
///
/// On the wire ffmpeg packs every band into a single opaque `args`
/// string with a positional grammar
/// (`attack,decay knee points crossover [delay [init_vol [gain]]]`,
/// bands joined by `|`). `McompandBandsX` hides that grammar — read
/// [McompandSettings.bands] for the typed view, write back via
/// [McompandSettings.withBands].
final class McompandBand {
  /// dB. Where compression starts. Negative.
  final double thresholdDb;

  /// Compression ratio, ≥ 1. (1.0 = no compression.)
  final double ratio;

  /// Seconds. Time-constant used by the compander's level detector
  /// when the input rises.
  final double attackSeconds;

  /// Seconds. Time-constant used when the input falls.
  final double releaseSeconds;

  /// Soft-knee width in dB. 0 = hard knee; larger smooths the
  /// compression curve around [thresholdDb].
  final double kneeDb;

  /// dB. Output makeup gain applied after compression.
  final double makeupDb;

  /// Hz. Upper edge of this band — anything above goes to the next
  /// band in `mcompand`'s filter chain.
  final double crossoverHz;

  const McompandBand({
    required this.thresholdDb,
    required this.ratio,
    required this.attackSeconds,
    required this.releaseSeconds,
    required this.kneeDb,
    required this.makeupDb,
    required this.crossoverHz,
  });

  McompandBand copyWith({
    double? thresholdDb,
    double? ratio,
    double? attackSeconds,
    double? releaseSeconds,
    double? kneeDb,
    double? makeupDb,
    double? crossoverHz,
  }) =>
      McompandBand(
        thresholdDb: thresholdDb ?? this.thresholdDb,
        ratio: ratio ?? this.ratio,
        attackSeconds: attackSeconds ?? this.attackSeconds,
        releaseSeconds: releaseSeconds ?? this.releaseSeconds,
        kneeDb: kneeDb ?? this.kneeDb,
        makeupDb: makeupDb ?? this.makeupDb,
        crossoverHz: crossoverHz ?? this.crossoverHz,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is McompandBand &&
          other.thresholdDb == thresholdDb &&
          other.ratio == ratio &&
          other.attackSeconds == attackSeconds &&
          other.releaseSeconds == releaseSeconds &&
          other.kneeDb == kneeDb &&
          other.makeupDb == makeupDb &&
          other.crossoverHz == crossoverHz);

  @override
  int get hashCode => Object.hash(thresholdDb, ratio, attackSeconds,
      releaseSeconds, kneeDb, makeupDb, crossoverHz);

  @override
  String toString() => 'McompandBand(threshold: $thresholdDb dB, '
      'ratio: $ratio, attack: $attackSeconds s, '
      'release: $releaseSeconds s, knee: $kneeDb dB, '
      'makeup: $makeupDb dB, crossover: $crossoverHz Hz)';
}

/// Typed access over the raw `args` string held by [McompandSettings].
///
/// The underlying lavfi grammar
/// (`attack,decay knee points crossover [delay [init_vol [gain]]]`,
/// bands joined by `|`) is a minor parser written in `af_mcompand.c`.
/// This extension mirrors that parser exactly. Round-trip is
/// lossless for bands produced by [withBands]; bands hand-written
/// with multi-segment transfer curves collapse to "ratio = last
/// segment's slope, threshold = last break" — informative for
/// editor display, lossy if echoed back unchanged.
extension McompandBandsX on McompandSettings {
  /// Decoded list of bands, sorted by ascending crossover.
  List<McompandBand> get bands => _parseMcompandBands(args);

  /// Returns a copy whose [args] reflects [bands] (ascending
  /// crossover order, lossless serialisation).
  McompandSettings withBands(List<McompandBand> bands) =>
      copyWith(args: _serializeMcompandBands(bands));
}

List<McompandBand> _parseMcompandBands(String? args) {
  if (args == null || args.trim().isEmpty) return const [];
  final out = <McompandBand>[];
  for (final raw in args.split('|')) {
    final fields = raw.trim().split(RegExp(r'\s+'));
    // Minimum 4 fields: attack,decay  knee  points  crossover.
    // Trailing 3 (delay, init_vol, gain) optional.
    if (fields.length < 4) continue;
    final ad = fields[0].split(',');
    if (ad.length != 2) continue;
    final attack = double.tryParse(ad[0]);
    final decay = double.tryParse(ad[1]);
    if (attack == null || decay == null) continue;
    final knee = double.tryParse(fields[1]) ?? 0;
    final pts = <(double, double)>[];
    for (final pair in fields[2].split(',')) {
      final xy = pair.split('/');
      if (xy.length == 2) {
        final x = double.tryParse(xy[0]);
        final y = double.tryParse(xy[1]);
        if (x != null && y != null) pts.add((x, y));
      }
    }
    pts.sort((a, b) => a.$1.compareTo(b.$1));
    final crossover = double.tryParse(fields[3]) ?? 0;
    final gain = fields.length > 6 ? (double.tryParse(fields[6]) ?? 0) : 0.0;

    // Reduce N transfer points to (threshold, ratio): the LAST
    // segment's slope inverse becomes the ratio, the second-to-last
    // input becomes the threshold. Lossless for bands [withBands]
    // produced (3-point compressor curves); lossy on hand-written
    // multi-segment curves.
    double threshold;
    double ratio;
    if (pts.length >= 2) {
      final last = pts.last;
      final prev = pts[pts.length - 2];
      final dIn = (last.$1 - prev.$1).abs();
      if (dIn < 1e-6) {
        threshold = prev.$1;
        ratio = 20.0;
      } else {
        final slope = (last.$2 - prev.$2) / dIn;
        ratio = slope.abs() < 1e-6 ? 20.0 : (1.0 / slope).clamp(1.0, 20.0);
        threshold = prev.$1;
      }
    } else {
      threshold = -24;
      ratio = 1;
    }

    out.add(McompandBand(
      thresholdDb: threshold,
      ratio: ratio,
      attackSeconds: attack,
      releaseSeconds: decay,
      kneeDb: knee,
      makeupDb: gain,
      crossoverHz: crossover,
    ));
  }
  out.sort((a, b) => a.crossoverHz.compareTo(b.crossoverHz));
  return out;
}

String _serializeMcompandBands(List<McompandBand> bands) {
  if (bands.isEmpty) return '';
  String fmtBand(McompandBand b) {
    // 3-point compressor curve: identity below threshold, slope
    // 1/ratio above. lavfi mcompand band grammar:
    //   attack,decay  knee  points  crossover  [delay  [init_vol  [gain]]]
    final outAtZero = b.thresholdDb + (0 - b.thresholdDb) / b.ratio;
    final pts = '-90/-90,'
        '${b.thresholdDb.toStringAsFixed(1)}/'
        '${b.thresholdDb.toStringAsFixed(1)},'
        '0/${outAtZero.toStringAsFixed(1)}';
    final tail = b.makeupDb.abs() > 1e-3
        // Need to fill in delay + init_vol with neutral defaults to
        // reach the gain field at position 6.
        ? ' 0 0 ${b.makeupDb.toStringAsFixed(1)}'
        : '';
    return '${b.attackSeconds.toStringAsFixed(4)},'
        '${b.releaseSeconds.toStringAsFixed(3)} '
        '${b.kneeDb.toStringAsFixed(1)} '
        '$pts ${b.crossoverHz.toStringAsFixed(0)}$tail';
  }

  final sorted = [...bands]
    ..sort((a, b) => a.crossoverHz.compareTo(b.crossoverHz));
  return sorted.map(fmtBand).join(' | ');
}
