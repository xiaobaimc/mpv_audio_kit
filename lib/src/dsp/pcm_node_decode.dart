// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be found in the LICENSE file.

import 'dart:ffi';
import 'dart:typed_data';

import '../mpv_bindings.dart';

/// Decodes a `MPV_FORMAT_BYTE_ARRAY` node of interleaved, host-order Float32
/// PCM — the wire format every audio tap (PCM tap, waveform, filter tap)
/// emits — into a fresh, aligned [Float32List]. Returns `null` for a
/// non-byte-array node or one too small to hold a single sample.
///
/// The bytes are copied out of the mpv-owned buffer first: that buffer is
/// freed at the end of the poll AND carries no 4-byte alignment guarantee, so
/// a direct `cast<Float>()` over it would be unsafe. The copy lands in a fresh
/// (aligned) buffer that is then reinterpreted as Float32 — host order ==
/// little-endian on every supported target, so this is both safe and
/// loop-free.
Float32List? decodeInterleavedFloat32(MpvNode node) {
  if (node.format != MpvFormat.mpvFormatByteArray) return null;
  final ba = node.u.ba.ref;
  if (ba.size < 4) return null;
  final n = ba.size ~/ 4;
  final bytes = Uint8List.fromList(ba.data.cast<Uint8>().asTypedList(n * 4));
  return bytes.buffer.asFloat32List(0, n);
}
