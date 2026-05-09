import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `stereotools`. Hero element is a
/// **lissajous vectorscope** — L+R samples plotted on a 45°-rotated
/// X/Y plane so vertical = mono content, horizontal = stereo width.
/// Below the scope, a **stereo correlation meter** (-1 inverted ↔ +1
/// mono) and a **L/R balance meter** read from the same paired tap.
///
/// Five knobs below: input level, output level, balance in, balance
/// out, M-level (M/S mid level). The remaining stereotools params
/// (sbal, mpan, base, sclevel, mode, bmode_*, delay, phase, mute*,
/// phase*, softclip) keep their defaults — they're niche and would
/// drown the headline editor; consumers who need them write through
/// `setAudioEffects` directly.
class StereotoolsWindow extends StatelessWidget {
  final VoidCallback onClose;
  const StereotoolsWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.stereotools;
        return ProPluginWindow(
          filterName: 'stereotools',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

double _ampToDb(double v) =>
    20 * (math.log(v.clamp(1e-9, 64.0)) / math.ln10);

double _dbToAmp(double db) => math.pow(10.0, db / 20.0).toDouble();

// Persistence ring — frames of phosphor history. At ~30 Hz tap, 30
// frames ≈ 1 s of decay, matching pro vectorscope feel.
const int _ringFrames = 30;

// ──────────────────────────────────────────────────────────────────────
// Graph — vectorscope + correlation + L/R balance.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final StereotoolsSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  // Rolling buffer of (L, R) pairs per frame. Each entry is one frame
  // worth of interleaved stereo samples; the scope painter walks the
  // most-recent N frames with decreasing alpha to produce the
  // phosphor-decay look.
  final List<Float32List> _frames = [];
  // Live correlation in [-1, +1] and balance in [-1, +1] (0 = centred).
  final _corr = ValueNotifier<double>(0);
  final _bal = ValueNotifier<double>(0);
  // Notifies the scope painter on each new frame.
  final _tick = ValueNotifier<int>(0);
  StreamSubscription<PcmFrame>? _sub;

  @override
  void initState() {
    super.initState();
    // We tap *post* so the scope reflects the actual stereo image the
    // listener will hear. Pre would just show the source.
    _sub = widget.player.stream
        .tap(AudioEffect.stereotools, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      if (pcm.channels != 2) return; // scope only meaningful in stereo
      _frames.add(pcm.samples);
      while (_frames.length > _ringFrames) {
        _frames.removeAt(0);
      }
      // Compute correlation + balance over this frame for the meters.
      final s = pcm.samples;
      var sumLL = 0.0, sumRR = 0.0, sumLR = 0.0;
      var peakL = 0.0, peakR = 0.0;
      for (var i = 0; i + 1 < s.length; i += 2) {
        final l = s[i];
        final r = s[i + 1];
        sumLL += l * l;
        sumRR += r * r;
        sumLR += l * r;
        if (l.abs() > peakL) peakL = l.abs();
        if (r.abs() > peakR) peakR = r.abs();
      }
      final denom = math.sqrt(sumLL * sumRR);
      final c = denom > 1e-9 ? (sumLR / denom).clamp(-1.0, 1.0) : 0.0;
      // EMA — correlation jitters frame-to-frame on real signals.
      _corr.value = _corr.value + 0.25 * (c - _corr.value);

      final p = peakL + peakR;
      final b = p > 1e-9 ? ((peakR - peakL) / p).clamp(-1.0, 1.0) : 0.0;
      _bal.value = _bal.value + 0.25 * (b - _bal.value);

      _tick.value = _tick.value + 1;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _corr.dispose();
    _bal.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ScopePainter(
                      frames: _frames,
                      tick: _tick,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _BipolarMeter(value: _corr, label: 'correlation', leftLabel: '-1 (inv)', rightLabel: '+1 (mono)'),
          const SizedBox(height: 4),
          _BipolarMeter(value: _bal, label: 'balance', leftLabel: 'L', rightLabel: 'R'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// Vectorscope painter — lissajous on the 45°-rotated plane.
//   X axis (horizontal) = L - R   (stereo width)
//   Y axis (vertical)   = L + R   (mono content)
// A 0 dB unit circle marks the saturation boundary; samples beyond
// the circle would clip on the analog domain.
// ──────────────────────────────────────────────────────────────────────

class _ScopePainter extends CustomPainter {
  final List<Float32List> frames;
  final ValueListenable<int> tick;
  _ScopePainter({required this.frames, required this.tick})
      : super(repaint: tick);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 4;

    // Crosshair + 0 dB unit circle.
    final guidePaint = Paint()
      ..color = ConsoleSkin.hairline
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = false;
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), guidePaint);
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), guidePaint);
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = true,
    );
    // 45° guides — mono (vertical) and inverse-mono diagonals.
    final diagPaint = Paint()
      ..color = ConsoleSkin.fgFaint
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = true;
    canvas.drawLine(
        Offset(cx - r, cy - r), Offset(cx + r, cy + r), diagPaint);
    canvas.drawLine(
        Offset(cx + r, cy - r), Offset(cx - r, cy + r), diagPaint);

    // Walk frames newest → oldest with exponential alpha decay so the
    // trace fades smoothly. Each frame is rendered as a connected
    // polyline (Lissajous convention) instead of discrete dots.
    if (frames.isEmpty) return;
    final newest = frames.length - 1;
    for (var f = 0; f < frames.length; f++) {
      final age = newest - f;
      final alpha = math.pow(0.85, age).toDouble() * 0.6;
      if (alpha < 0.01) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..isAntiAlias = true
        ..color = ConsoleSkin.accent.withValues(alpha: alpha);

      final s = frames[f];
      // Decimate so we don't draw 4096 points per frame (~30 Hz × 4096
      // = 120k draws/s — pegs the GPU). Stride to ~256 points per frame.
      final pairCount = s.length ~/ 2;
      final stride = math.max(1, pairCount ~/ 256);
      final path = Path();
      var first = true;
      for (var i = 0; i < pairCount; i += stride) {
        final l = s[i * 2];
        final rs = s[i * 2 + 1];
        // Rotate L,R by 45° so mono content (L=R) walks the vertical
        // axis. Standard vectorscope orientation.
        final x = (l - rs) * 0.707; // M = (L+R)/sqrt(2), S = (L-R)/sqrt(2)
        final y = (l + rs) * 0.707;
        final px = cx + x * r;
        final py = cy - y * r;
        if (first) {
          path.moveTo(px, py);
          first = false;
        } else {
          path.lineTo(px, py);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ScopePainter old) => false;
}

// ──────────────────────────────────────────────────────────────────────
// Bipolar meter — center-zero horizontal bar, value in [-1, +1] reads
// as a fill from the centerline to either left or right.
// ──────────────────────────────────────────────────────────────────────

class _BipolarMeter extends StatelessWidget {
  final ValueListenable<double> value;
  final String label;
  final String leftLabel;
  final String rightLabel;
  const _BipolarMeter({
    required this.value,
    required this.label,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: ConsoleSkin.fontMono,
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              leftLabel,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: ConsoleSkin.fontMono,
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgFaint,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SizedBox(
              height: 16,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BipolarPainter(value: value),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            child: Text(
              rightLabel,
              style: const TextStyle(
                fontFamily: ConsoleSkin.fontMono,
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BipolarPainter extends CustomPainter {
  final ValueListenable<double> value;
  _BipolarPainter({required this.value}) : super(repaint: value);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bg);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = ConsoleSkin.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
    final cx = size.width / 2;
    // Center hairline.
    canvas.drawLine(
      Offset(cx.floorToDouble() + 0.5, 0),
      Offset(cx.floorToDouble() + 0.5, size.height),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = ConsoleSkin.hairlinePx
        ..isAntiAlias = false,
    );
    final v = value.value.clamp(-1.0, 1.0);
    final w = (size.width / 2 * v.abs()).abs();
    final left = v >= 0 ? cx : cx - w;
    canvas.drawRect(
      Rect.fromLTWH(left, 2, w, size.height - 4),
      Paint()..color = ConsoleSkin.accent,
    );
  }

  @override
  bool shouldRepaint(_BipolarPainter old) => false;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — five knobs.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final StereotoolsSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(StereotoolsSettings next) {
    player.updateAudioEffects((b) => b.copyWith(stereotools: next));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            value: _ampToDb(settings.level_in),
            min: -36,
            max: 36,
            defaultValue: _ampToDb(StereotoolsSettings.level_inDefault),
            onChanged: (db) => _apply(settings.copyWith(
              level_in: _dbToAmp(db).clamp(
                StereotoolsSettings.level_inMin,
                StereotoolsSettings.level_inMax,
              ),
            )),
            label: 'in dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.level_out),
            min: -36,
            max: 36,
            defaultValue: _ampToDb(StereotoolsSettings.level_outDefault),
            onChanged: (db) => _apply(settings.copyWith(
              level_out: _dbToAmp(db).clamp(
                StereotoolsSettings.level_outMin,
                StereotoolsSettings.level_outMax,
              ),
            )),
            label: 'out dB',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.balance_in,
            min: StereotoolsSettings.balance_inMin,
            max: StereotoolsSettings.balance_inMax,
            defaultValue: StereotoolsSettings.balance_inDefault,
            onChanged: (v) => _apply(settings.copyWith(balance_in: v)),
            label: 'bal in',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.balance_out,
            min: StereotoolsSettings.balance_outMin,
            max: StereotoolsSettings.balance_outMax,
            defaultValue: StereotoolsSettings.balance_outDefault,
            onChanged: (v) => _apply(settings.copyWith(balance_out: v)),
            label: 'bal out',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.mlev),
            min: -36,
            max: 36,
            defaultValue: _ampToDb(StereotoolsSettings.mlevDefault),
            onChanged: (db) => _apply(settings.copyWith(
              mlev: _dbToAmp(db).clamp(
                StereotoolsSettings.mlevMin,
                StereotoolsSettings.mlevMax,
              ),
            )),
            label: 'mid lev',
            format: (v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}',
            size: 70,
          ),
        ],
      ),
    );
  }
}
