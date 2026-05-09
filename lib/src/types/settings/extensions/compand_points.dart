// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/src/types/settings/audio_effects_settings.dart';

/// One break-point of the lavfi `compand` filter's transfer function.
///
/// The transfer function is a piecewise linear mapping of input dB
/// to output dB; consecutive [CompandPoint]s define the segments.
/// `compand` interpolates between them — outside the range of the
/// declared points the output is clipped to the nearest break.
final class CompandPoint {
  /// Input level in dB.
  final double inDb;

  /// Output level in dB.
  final double outDb;

  const CompandPoint({required this.inDb, required this.outDb});

  CompandPoint copyWith({double? inDb, double? outDb}) =>
      CompandPoint(inDb: inDb ?? this.inDb, outDb: outDb ?? this.outDb);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompandPoint &&
          other.inDb == inDb &&
          other.outDb == outDb);

  @override
  int get hashCode => Object.hash(inDb, outDb);

  @override
  String toString() => 'CompandPoint(in: $inDb dB, out: $outDb dB)';
}

/// Typed access over the `points` string lavfi's `compand` carries
/// (space-separated `inDb/outDb` pairs).
extension CompandPointsX on CompandSettings {
  /// Decoded transfer-function points, sorted by ascending input.
  List<CompandPoint> get transferPoints {
    final src = points;
    if (src == null || src.trim().isEmpty) return const [];
    final out = <CompandPoint>[];
    for (final pair in src.trim().split(RegExp(r'\s+'))) {
      final xy = pair.split('/');
      if (xy.length != 2) continue;
      final x = double.tryParse(xy[0]);
      final y = double.tryParse(xy[1]);
      if (x != null && y != null) {
        out.add(CompandPoint(inDb: x, outDb: y));
      }
    }
    out.sort((a, b) => a.inDb.compareTo(b.inDb));
    return out;
  }

  /// Returns a copy whose [points] reflects [points] (ascending
  /// input order). Empty input clears the transfer function.
  CompandSettings withTransferPoints(List<CompandPoint> points) {
    if (points.isEmpty) return copyWith(points: '');
    final sorted = [...points]..sort((a, b) => a.inDb.compareTo(b.inDb));
    return copyWith(
      points: sorted
          .map((p) =>
              '${p.inDb.toStringAsFixed(1)}/${p.outDb.toStringAsFixed(1)}')
          .join(' '),
    );
  }
}
