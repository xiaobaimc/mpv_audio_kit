import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_level_meter.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `deesser`. Hero element is a live
/// spectrum (post-filter) with the **sibilance band** highlighted in
/// accent — a vertical band around the de-esser's centre frequency,
/// scaled by the `m` (max attenuation depth) parameter so the user
/// sees, in real time, how much of the upper midrange is being
/// targeted. When the de-esser is biting the band darkens.
///
/// FabFilter Pro-DS / Sonnox SuprEsser use exactly this metaphor — a
/// "moving beam" that tells the listener "this is the slice I'm
/// guarding". Three knobs below: intensity (`i`), frequency (`f`),
/// max depth (`m`). The de-esser's `s` (single / split) mode keeps
/// its default — the binary choice is best left in `setAudioEffects`.
class DeesserWindow extends StatelessWidget {
  final VoidCallback onClose;
  const DeesserWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.deesser;
        return ProPluginWindow(
          filterName: 'deesser',
          onClose: onClose,
          graph: _Graph(settings: s, player: p),
          controls: _Controls(settings: s, player: p),
        );
      },
    );
  }
}

// lavfi `f` is normalised 0..1 mapping linearly to a band that lavfi
// sweeps between roughly 2 kHz and 14 kHz — the typical sibilance
// range. Doc isn't crisp on the exact endpoints; these are the
// musically-useful bounds and align with FabFilter Pro-DS's frequency
// knob range.
const double _fLowHz = 2000;
const double _fHighHz = 14000;

double _bandCenterHz(double f) =>
    _fLowHz + f.clamp(0.0, 1.0) * (_fHighHz - _fLowHz);

// Bandwidth around the centre — `m` (max) widens it. m=0 → ~600 Hz
// wide, m=1 → ~2 kHz wide. Roughly matches the typical Q of a
// musically-tuned sibilance EQ.
double _bandWidthHz(double m) => 600 + m.clamp(0.0, 1.0) * 1400;

// ──────────────────────────────────────────────────────────────────────
// Graph
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final DeesserSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  // Same FFT pipeline the global visualizer uses, fed by the
  // post-filter tap so the spectrum reflects what the de-esser is
  // actually outputting.
  final _bands = ValueNotifier<Float32List?>(null);
  // RMS-based gain reduction in dB. (preRms - postRms) — same pattern
  // the compressor window uses; peak-vs-peak under-reports because
  // sibilance transients escape the de-esser's attack.
  final _grDb = ValueNotifier<double>(0);
  late BandProcessor _proc;
  StreamSubscription<PcmFrame>? _preSub;
  StreamSubscription<PcmFrame>? _postSub;
  StreamSubscription<SpectrumSettings>? _cfgSub;
  double _preRmsDb = -60;
  double _postRmsDb = -60;

  static const double _grMaxDb = 24;

  @override
  void initState() {
    super.initState();
    _proc = BandProcessor(widget.player.spectrumSettings);
    _cfgSub = widget.player.stream.spectrum.listen(_proc.setSettings);
    _preSub = widget.player.stream
        .tap(AudioEffect.deesser, side: TapSide.pre)
        .listen((pcm) {
      if (!mounted) return;
      _preRmsDb = _rmsDb(pcm, _preRmsDb);
      _emitGr();
    });
    _postSub = widget.player.stream
        .tap(AudioEffect.deesser, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      final f = _proc.process(pcm);
      if (f != null) _bands.value = f.bands;
      _postRmsDb = _rmsDb(pcm, _postRmsDb);
      _emitGr();
    });
  }

  /// Emit the meter's input as a NEGATIVE dB so [MeterDirection.downFromTop]
  /// fills downward as the de-esser bites harder. Range [-grMaxDb, 0].
  void _emitGr() {
    final gr = (_preRmsDb - _postRmsDb).clamp(0.0, _grMaxDb);
    _grDb.value = -gr;
  }

  /// Short-term RMS in dB with symmetric medium-fast smoothing.
  double _rmsDb(PcmFrame f, double prev) {
    final s = f.samples;
    if (s.isEmpty) return prev;
    var sumSq = 0.0;
    for (var i = 0; i < s.length; i++) {
      final v = s[i];
      sumSq += v * v;
    }
    final rms = math.sqrt(sumSq / s.length);
    final db = rms <= 1e-6 ? -60.0 : 20 * (math.log(rms) / math.ln10);
    final clamped = db.clamp(-60.0, 0.0);
    return prev + 0.3 * (clamped - prev);
  }

  @override
  void dispose() {
    _preSub?.cancel();
    _postSub?.cancel();
    _cfgSub?.cancel();
    _bands.dispose();
    _grDb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _DeesserPainter(
                  settings: widget.settings,
                  bands: _bands,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // GR strip — fills DOWNWARD from the top as the de-esser bites.
          // Source feeds dB directly; -grMaxDb at the top represents max
          // attenuation, 0 at the bottom is "no reduction".
          SizedBox(
            width: 22,
            child: AtomLevelMeter(
              source: _grDb,
              sourceInDb: true,
              minDb: -_grMaxDb,
              maxDb: 0,
              amberDb: -12,
              redDb: -6,
              direction: MeterDirection.downFromTop,
              width: 14,
              label: 'GR',
            ),
          ),
        ],
      ),
    );
  }
}

class _DeesserPainter extends CustomPainter {
  final DeesserSettings settings;
  final ValueListenable<Float32List?> bands;
  _DeesserPainter({required this.settings, required this.bands})
      : super(repaint: bands);

  static const double _bandLow = 20;
  static const double _bandHigh = 20000;

  static const _freqGridMajor = [50, 100, 1000, 10000];
  static const _freqGridMinor = [200, 500, 2000, 5000, 20000];

  double _xOfHz(double hz, Size size) {
    final plot = PlotChrome.plotRect(size);
    final t = (math.log(hz.clamp(_bandLow, _bandHigh) / _bandLow) /
            math.log(_bandHigh / _bandLow))
        .clamp(0.0, 1.0);
    return plot.left + plot.width * t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = PlotChrome.plotRect(size);
    canvas.drawRect(plot, Paint()..color = ConsoleSkin.bgDeep);

    // Two-tier frequency grid: minors first, majors on top.
    for (final hz in _freqGridMinor) {
      PlotChrome.drawVGrid(canvas, size, _xOfHz(hz.toDouble(), size));
    }
    for (final hz in _freqGridMajor) {
      PlotChrome.drawVGrid(canvas, size, _xOfHz(hz.toDouble(), size),
          color: ConsoleSkin.fgFaint);
    }

    // Sibilance band — translucent vertical strip centred at `f`, wide
    // as `_bandWidthHz(m)`. Accent darkens with intensity `i`.
    final centre = _bandCenterHz(settings.f);
    final width = _bandWidthHz(settings.m);
    final lo = (centre - width / 2).clamp(_bandLow, _bandHigh);
    final hi = (centre + width / 2).clamp(_bandLow, _bandHigh);
    final xLo = _xOfHz(lo, size);
    final xHi = _xOfHz(hi, size);
    final intensity = settings.i.clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTRB(xLo, plot.top, xHi, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accent.withValues(alpha: 0.12 + 0.18 * intensity),
    );
    // Centre line of the band.
    final cx = _xOfHz(centre, size).floorToDouble() + 0.5;
    canvas.drawLine(
      Offset(cx, plot.top),
      Offset(cx, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accent
        ..strokeWidth = 1
        ..isAntiAlias = true,
    );

    // Spectrum on top — bottom 70% of the plot rect.
    final v = bands.value;
    if (v != null && v.isNotEmpty) {
      SpectrumCurve.paintOn(
        canvas,
        Rect.fromLTWH(
          plot.left,
          plot.top + plot.height * 0.30,
          plot.width,
          plot.height * 0.70,
        ),
        v,
        color: ConsoleSkin.fg,
        fillAlpha: 0.20,
        strokeWidth: 1.2,
      );
    }

    // Frequency labels along the bottom gutter.
    for (final hz in _freqGridMajor) {
      PlotChrome.drawXLabel(canvas, size, _xOfHz(hz.toDouble(), size),
          PlotChrome.formatHz(hz));
    }
  }

  @override
  bool shouldRepaint(_DeesserPainter old) => old.settings != settings;
}

// ──────────────────────────────────────────────────────────────────────
// Controls
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final DeesserSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(DeesserSettings next) {
    player.updateAudioEffects((b) => b.copyWith(deesser: next));
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
            value: settings.i,
            min: DeesserSettings.iMin,
            max: DeesserSettings.iMax,
            defaultValue: DeesserSettings.iDefault,
            onChanged: (v) => _apply(settings.copyWith(i: v)),
            label: 'intensity',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.f,
            min: DeesserSettings.fMin,
            max: DeesserSettings.fMax,
            defaultValue: DeesserSettings.fDefault,
            onChanged: (v) => _apply(settings.copyWith(f: v)),
            label: 'freq',
            format: (v) {
              final hz = _bandCenterHz(v);
              if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
              return hz.toStringAsFixed(0);
            },
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.m,
            min: DeesserSettings.mMin,
            max: DeesserSettings.mMax,
            defaultValue: DeesserSettings.mDefault,
            onChanged: (v) => _apply(settings.copyWith(m: v)),
            label: 'max',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
        ],
      ),
    );
  }
}
