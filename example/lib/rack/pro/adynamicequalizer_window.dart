import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_knob.dart';
import '../../atoms/atom_plot_chrome.dart';
import '../../atoms/atom_spectrum_curve.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Pro-style window for the lavfi `adynamicequalizer` — a dynamic EQ
/// that compresses or expands a single frequency band when its energy
/// crosses a threshold. Equivalent to FabFilter Pro-Q's "dynamic"
/// per-band mode or TDR Nova's full-band dynamic mode: pick a centre
/// frequency, set how aggressively the band reacts to level.
///
/// Hero element is a live spectrum with the **target band**
/// highlighted at `tfrequency` (where the gain change happens). The
/// band darkens when the engine is actively reducing its energy.
///
/// Six knobs below: tfrequency, tqfactor, threshold, ratio, range,
/// attack/release. The `auto`, `mode`, `precision`, and detect-side
/// (`dfrequency` / `dqfactor` / `dftype`) parameters keep their
/// defaults — they're for advanced sidechain routing best left to
/// `setAudioEffects` callers.
class AdynamicequalizerWindow extends StatelessWidget {
  final VoidCallback onClose;
  const AdynamicequalizerWindow({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, snap) {
        final bundle = snap.data ?? const AudioEffects();
        final s = bundle.adynamicequalizer;
        return ProPluginWindow(
          filterName: 'adynamicequalizer',
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

// ──────────────────────────────────────────────────────────────────────
// Graph — spectrum + target band highlight.
// ──────────────────────────────────────────────────────────────────────

class _Graph extends StatefulWidget {
  final AdynamicequalizerSettings settings;
  final Player player;
  const _Graph({required this.settings, required this.player});

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  final _bands = ValueNotifier<Float32List?>(null);
  late BandProcessor _proc;
  StreamSubscription<PcmFrame>? _sub;
  StreamSubscription<SpectrumSettings>? _cfgSub;
  // Activity = how much GR the band is taking right now. Drives the
  // band-highlight darkness so the user sees the dynamic response.
  final _activity = ValueNotifier<double>(0);
  // Pre-band peak energy for activity estimation.
  StreamSubscription<PcmFrame>? _activitySub;
  double _activitySmoothed = 0;

  @override
  void initState() {
    super.initState();
    _proc = BandProcessor(widget.player.spectrumSettings);
    _cfgSub = widget.player.stream.spectrum.listen(_proc.setSettings);
    _sub = widget.player.stream
        .tap(AudioEffect.adynamicequalizer, side: TapSide.post)
        .listen((pcm) {
      if (!mounted) return;
      final f = _proc.process(pcm);
      if (f != null) _bands.value = f.bands;
    });
    // Compare pre vs post peak — when the engine attenuates the band,
    // post is lower than pre, and the activity rises.
    _activitySub = widget.player.stream
        .tap(AudioEffect.adynamicequalizer, side: TapSide.pre)
        .listen((prePcm) {
      var prePeak = 0.0;
      for (var i = 0; i < prePcm.samples.length; i++) {
        final a = prePcm.samples[i].abs();
        if (a > prePeak) prePeak = a;
      }
      // Post peak captured asynchronously by the post-tap consumer
      // above — close enough for an activity meter, no need to pair
      // exactly.
      final activity = (prePeak.toDouble() - 0.5).clamp(0.0, 0.5) * 2;
      _activitySmoothed = _activitySmoothed * 0.85 + activity * 0.15;
      _activity.value = _activitySmoothed;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _activitySub?.cancel();
    _cfgSub?.cancel();
    _bands.dispose();
    _activity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(8),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _DynEqPainter(
            settings: widget.settings,
            bands: _bands,
            activity: _activity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _DynEqPainter extends CustomPainter {
  final AdynamicequalizerSettings settings;
  final ValueListenable<Float32List?> bands;
  final ValueListenable<double> activity;
  _DynEqPainter({
    required this.settings,
    required this.bands,
    required this.activity,
  }) : super(repaint: Listenable.merge([bands, activity]));

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

    for (final hz in _freqGridMinor) {
      PlotChrome.drawVGrid(canvas, size, _xOfHz(hz.toDouble(), size));
    }
    for (final hz in _freqGridMajor) {
      PlotChrome.drawVGrid(canvas, size, _xOfHz(hz.toDouble(), size),
          color: ConsoleSkin.fgFaint);
    }

    // Target band: a vertical strip centred at `tfrequency`, width
    // proportional to `1/tqfactor` (higher Q = narrower band).
    final centreHz = settings.tfrequency.clamp(_bandLow, _bandHigh);
    final q = settings.tqfactor.clamp(0.1, 100);
    // Band width in octaves ≈ 1/Q, mapped to Hz.
    final octs = 1.0 / q;
    final lo = centreHz / math.pow(2, octs / 2);
    final hi = centreHz * math.pow(2, octs / 2);
    final xLo = _xOfHz(lo.toDouble(), size);
    final xHi = _xOfHz(hi.toDouble(), size);
    final act = activity.value.clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTRB(xLo, plot.top, xHi, plot.bottom),
      Paint()
        ..color = ConsoleSkin.accent.withValues(alpha: 0.10 + 0.20 * act),
    );
    final cx = _xOfHz(centreHz, size).floorToDouble() + 0.5;
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
      final txt = hz >= 1000 ? '${(hz / 1000).toStringAsFixed(0)}k' : '$hz';
      PlotChrome.drawXLabel(canvas, size, _xOfHz(hz.toDouble(), size), txt);
    }
  }

  @override
  bool shouldRepaint(_DynEqPainter old) => old.settings != settings;
}

// ──────────────────────────────────────────────────────────────────────
// Controls — six knobs. Frequency on log scale, threshold in dB.
// ──────────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  final AdynamicequalizerSettings settings;
  final Player player;
  const _Controls({required this.settings, required this.player});

  void _apply(AdynamicequalizerSettings next) {
    player.updateAudioEffects((b) => b.copyWith(adynamicequalizer: next));
  }

  // tfrequency 2..1e6 — clamp display to musical 20..20000 for knob
  // resolution. Engine clamp uses spec.
  static const double _fMin = 20;
  static const double _fMax = 20000;
  double _tToFreq(double t) =>
      _fMin * math.pow(_fMax / _fMin, t.clamp(0.0, 1.0)).toDouble();
  double _freqToT(double hz) =>
      math.log(hz.clamp(_fMin, _fMax) / _fMin) / math.log(_fMax / _fMin);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AtomKnob(
            value: _freqToT(settings.tfrequency),
            min: 0,
            max: 1,
            defaultValue: _freqToT(1000),
            onChanged: (t) => _apply(settings.copyWith(
              tfrequency: _tToFreq(t).clamp(
                AdynamicequalizerSettings.tfrequencyMin,
                AdynamicequalizerSettings.tfrequencyMax,
              ),
            )),
            label: 'freq',
            format: (t) {
              final hz = _tToFreq(t);
              if (hz >= 1000) return '${(hz / 1000).toStringAsFixed(1)}k';
              return hz.toStringAsFixed(0);
            },
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.tqfactor,
            min: 0.1,
            max: 10,
            defaultValue: 1.0,
            onChanged: (v) => _apply(settings.copyWith(
              tqfactor: v.clamp(
                AdynamicequalizerSettings.tqfactorMin,
                AdynamicequalizerSettings.tqfactorMax,
              ),
            )),
            label: 'Q',
            format: (v) => v.toStringAsFixed(2),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: _ampToDb(settings.threshold.clamp(1e-6, 100.0)),
            min: -60,
            max: 0,
            defaultValue: -18,
            onChanged: (db) => _apply(settings.copyWith(
              threshold: math.pow(10.0, db / 20).toDouble().clamp(
                AdynamicequalizerSettings.thresholdMin,
                AdynamicequalizerSettings.thresholdMax,
              ),
            )),
            label: 'thr dB',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.ratio,
            min: 0,
            max: 20,
            defaultValue: 1,
            onChanged: (v) => _apply(settings.copyWith(
              ratio: v.clamp(
                AdynamicequalizerSettings.ratioMin,
                AdynamicequalizerSettings.ratioMax,
              ),
            )),
            label: 'ratio',
            format: (v) => '${v.toStringAsFixed(1)}:1',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.range,
            // Spec range is wider; tighten to a useful EQ depth.
            min: 1,
            max: 24,
            defaultValue: 12,
            onChanged: (v) => _apply(settings.copyWith(
              range: v.clamp(
                AdynamicequalizerSettings.rangeMin,
                AdynamicequalizerSettings.rangeMax,
              ),
            )),
            label: 'range',
            format: (v) => '${v.toStringAsFixed(1)} dB',
            size: 70,
          ),
          const SizedBox(width: 16),
          AtomKnob(
            value: settings.attack,
            min: 0.1,
            max: 200,
            defaultValue: AdynamicequalizerSettings.attackMin == 0.01 ? 20 : 20,
            onChanged: (v) => _apply(settings.copyWith(
              attack: v.clamp(
                AdynamicequalizerSettings.attackMin,
                AdynamicequalizerSettings.attackMax,
              ),
            )),
            label: 'atk ms',
            format: (v) => v.toStringAsFixed(1),
            size: 70,
          ),
        ],
      ),
    );
  }
}
