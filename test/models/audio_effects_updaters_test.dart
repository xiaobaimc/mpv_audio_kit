// Copyright © 2026 & onwards, Alessandro Di Ronza <ales.drnz@gmail.com>.
// All rights reserved.
// Use of this source code is governed by BSD 3-Clause license that can be
// found in the LICENSE file.

import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:test/test.dart';

void main() {
  group('AudioEffects per-slot updaters', () {
    test('updater on a never-configured slot seeds the defaults', () {
      const e = AudioEffects();
      final next = e.updateBass((b) => b.copyWith(enabled: true));
      expect(next.bass, isNotNull);
      expect(next.bass!.enabled, isTrue);
      // Every other param sits at its ffmpeg default.
      expect(next.bass!.g, const BassSettings().g);
      expect(next.bass!.f, const BassSettings().f);
    });

    test('updater preserves previously-set params', () {
      const e = AudioEffects(bass: BassSettings(enabled: true, g: 4));
      final next = e.updateBass((b) => b.copyWith(enabled: false));
      expect(next.bass!.enabled, isFalse);
      expect(next.bass!.g, 4, reason: 'disable must keep the gain');
    });

    test('updater leaves every other slot untouched (null stays null)', () {
      const e = AudioEffects();
      final next = e.updateBass((b) => b.copyWith(enabled: true));
      expect(next.treble, isNull);
      expect(next.acompressor, isNull);
    });

    test('null slot and disabled instance emit the same af chain', () {
      const absent = AudioEffects();
      // BassSettings defaults to enabled: false — configured but inactive.
      const disabled = AudioEffects(bass: BassSettings(g: 4));
      expect(absent.toAfChain(), disabled.toAfChain());
      expect(absent.toAfChain(), isEmpty);
    });

    test('updater chain composes with Player.updateAudioEffects shape', () {
      // The documented one-liner: toggle through both mappers.
      const e = AudioEffects();
      final on = e.updateAcompressor((c) => c.copyWith(enabled: !c.enabled));
      expect(on.acompressor!.enabled, isTrue);
      final off = on.updateAcompressor((c) => c.copyWith(enabled: !c.enabled));
      expect(off.acompressor!.enabled, isFalse);
    });
  });
}
