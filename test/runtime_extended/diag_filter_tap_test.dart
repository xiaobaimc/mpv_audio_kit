// Diagnostic — not part of the suite. Subscribes to tapPost and
// logs timing + sample fingerprint to see exactly what flows.
@TestOn('mac-os || linux || windows')
library;

import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import '../_helpers/setter_test_helpers.dart';

void main() {
  final fixture = '${Directory.current.path}/test/fixtures/sine_5s.flac';
  setUpAll(() => initLibmpvOrSkip(fixturePath: fixture));

  test('diag: trace tapPost frames', () async {
    final player = await buildPlayer();
    try {
      await player.setAudioEffects(const AudioEffects(
        equalizer: EqualizerSettings(enabled: true),
      ));
      await openAndWaitForLoad(player, fixture);

      // Wait for the global pcm-tap to start flowing — proves audio
      // is actually streaming.
      final pcmReady = Completer<void>();
      final pcmSub = player.stream.pcm.listen((_) {
        if (!pcmReady.isCompleted) pcmReady.complete();
      });
      await player.play();
      await pcmReady.future.timeout(const Duration(seconds: 3));
      await pcmSub.cancel();
      print('[diag] global pcm tap flowing');

      // Now subscribe to tapPost and log every frame.
      final t0 = DateTime.now().millisecondsSinceEpoch;
      var prevTs = 0;
      var prevFp = 0.0;
      var count = 0;
      var prevFirst = 0.0;
      final sub = player.tapPost('equalizer').listen((frame) {
        final tWall = DateTime.now().millisecondsSinceEpoch - t0;
        final ts = frame.timestamp.inMilliseconds;
        final dTs = ts - prevTs;
        final first = frame.samples.first;
        final last = frame.samples.last;
        final dFirst = (first - prevFirst).abs();
        print('[diag] #${count.toString().padLeft(3)} '
            'tWall=${tWall.toString().padLeft(5)}ms  '
            'ts=${ts.toString().padLeft(7)}ms (Δ${dTs.toString().padLeft(5)}ms)  '
            'first=${first.toStringAsFixed(6).padLeft(10)} '
            '(Δ${dFirst.toStringAsFixed(6).padLeft(10)})  '
            'last=${last.toStringAsFixed(6).padLeft(10)}');
        prevTs = ts;
        prevFirst = first;
        prevFp = 0;  // unused
        count++;
      });

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      await sub.cancel();
      print('[diag] received $count frames in ~1.5s');
    } finally {
      await player.pause();
      await player.dispose();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
