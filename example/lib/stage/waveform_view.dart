import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import '../skin/paint_helpers.dart';

/// Full-track waveform with a Reaper-style time ruler on top.
///
/// At [zoomLevel] = 1 the entire track is visible. At higher zooms the
/// view auto-centres on the playhead UNTIL the user pans with the
/// trackpad / wheel — after that the view sticks where the user left
/// it. Toolbar zoom buttons re-engage auto-follow; **Cmd / Ctrl +
/// wheel** zooms anchored at the mouse position (the standard "zoom
/// at cursor" pattern from Reaper, Logic, etc.).
///
/// A grey hover cursor follows the mouse while inside the strip,
/// previewing where a click would seek.
class WaveformView extends StatefulWidget {
  final int zoomLevel;
  /// Allowed zoom range. The wheel-zoom shortcut respects these bounds;
  /// outside them the wheel falls through to a normal pan.
  final int zoomMin;
  final int zoomMax;
  /// Fired when the user changes zoom via Cmd / Ctrl + wheel so the
  /// owning widget can keep its [zoomLevel] state in sync.
  final ValueChanged<int>? onZoomChanged;

  const WaveformView({
    super.key,
    this.zoomLevel = 1,
    this.zoomMin = 1,
    this.zoomMax = 16,
    this.onZoomChanged,
  });

  @override
  State<WaveformView> createState() => _WaveformViewState();
}

class _WaveformViewState extends State<WaveformView> {
  /// Left edge of the visible window as a track fraction in [0, 1).
  /// Only consulted when [_userPanned] is true; otherwise the view
  /// auto-centres on the playhead so playback never scrolls off.
  double _scrollFraction = 0;
  /// True after the first trackpad / wheel pan. Switches the view from
  /// auto-follow-playhead to explicit-scroll. Toolbar zoom changes
  /// reset this back to false; wheel-zoom keeps it true so the mouse-
  /// anchor [_scrollFraction] survives the rebuild.
  bool _userPanned = false;
  /// Mouse x while hovering the strip; null when the cursor is
  /// outside. Drives the grey vertical preview line.
  double? _hoverX;
  /// Throttle the wheel-zoom path: the trackpad emits dozens of scroll
  /// events per "tick", but our zoom levels are powers of two — one
  /// step per ~120 ms keeps the gesture responsive without slingshot-
  /// ing through the whole range on a single swipe.
  DateTime _lastWheelZoomAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const _wheelZoomCooldown = Duration(milliseconds: 120);
  /// Set true while we're in the middle of dispatching a wheel-zoom so
  /// the next [didUpdateWidget] keeps [_userPanned] sticky instead of
  /// re-engaging auto-follow.
  bool _zoomedViaWheel = false;

  @override
  void didUpdateWidget(WaveformView old) {
    super.didUpdateWidget(old);
    if (old.zoomLevel != widget.zoomLevel) {
      if (_zoomedViaWheel) {
        // Wheel-zoom path: [_scrollFraction] was already set to anchor
        // the mouse position; keep it sticky across the rebuild.
        _zoomedViaWheel = false;
      } else {
        // Toolbar / external zoom change re-engages auto-follow so
        // the user lands back on the playhead.
        _userPanned = false;
      }
    }
  }

  void _seekToX(
    Player player,
    double x,
    double w,
    Duration dur,
    double viewStart,
    double viewEnd,
  ) {
    if (dur == Duration.zero || w <= 0) return;
    final localFrac = (x / w).clamp(0.0, 1.0);
    final globalFrac = viewStart + localFrac * (viewEnd - viewStart);
    final clamped = globalFrac.clamp(0.0, 1.0);
    player.seek(Duration(milliseconds: (dur.inMilliseconds * clamped).round()));
  }

  void _pan(double pixels, double containerWidth, double visibleWidth) {
    if (visibleWidth >= 1.0 || containerWidth <= 0) return;
    final fracDelta = (pixels / containerWidth) * visibleWidth;
    setState(() {
      _userPanned = true;
      _scrollFraction =
          (_scrollFraction + fracDelta).clamp(0.0, 1.0 - visibleWidth);
    });
  }

  /// Bumps the zoom one step in [direction] (+1 = in, -1 = out) so
  /// the time at the mouse position stays at the mouse position. The
  /// owning widget is notified via [WaveformView.onZoomChanged]; the
  /// view re-engages auto-follow only when the bump comes from
  /// somewhere else (e.g. toolbar buttons), not from this path.
  void _zoomAtMouse(
    double mouseX,
    double containerWidth,
    int direction,
    double viewStart,
    double viewEnd,
  ) {
    final cb = widget.onZoomChanged;
    if (cb == null || containerWidth <= 0) return;

    // Step the zoom on the same multiplicative scale the toolbar uses
    // (1, 2, 4, 8, 16). One step per scroll burst, throttled below.
    final cur = widget.zoomLevel;
    final next = direction > 0 ? cur * 2 : cur ~/ 2;
    final clamped = next.clamp(widget.zoomMin, widget.zoomMax);
    if (clamped == cur) return;

    // Anchor: time-fraction under the cursor must be the same before
    // and after. Solve `viewStart' = tMouse - (mouseX/W) * newWidth`.
    final mouseFrac = (mouseX / containerWidth).clamp(0.0, 1.0);
    final tMouse = viewStart + mouseFrac * (viewEnd - viewStart);
    final newVisible = 1.0 / clamped;
    final newScroll = newVisible >= 1.0
        ? 0.0
        : (tMouse - mouseFrac * newVisible).clamp(0.0, 1.0 - newVisible);

    setState(() {
      _userPanned = clamped > 1;       // no point sticking when fully zoomed out
      _scrollFraction = newScroll;
      _zoomedViaWheel = true;
      _lastWheelZoomAt = DateTime.now();
    });
    cb(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final player = StudioScope.of(context);
    return StreamBuilder<WaveformData?>(
      stream: player.stream.waveform,
      builder: (ctx, waveSnap) => StreamBuilder<Duration>(
        stream: player.stream.position,
        builder: (ctx, posSnap) => StreamBuilder<Duration>(
          stream: player.stream.duration,
          builder: (ctx, durSnap) {
            final wave = waveSnap.data;
            final pos = posSnap.data ?? Duration.zero;
            final dur = durSnap.data ?? Duration.zero;

            final visibleWidth = 1.0 / widget.zoomLevel;
            // Auto-follow: keep the playhead centred until the user
            // pans. After a pan, [_scrollFraction] is the source of
            // truth and the playhead can leave the visible window.
            final double effectiveStart;
            if (_userPanned) {
              effectiveStart =
                  _scrollFraction.clamp(0.0, 1.0 - visibleWidth);
            } else {
              final pf = dur.inMilliseconds > 0
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;
              effectiveStart =
                  (pf - visibleWidth / 2).clamp(0.0, 1.0 - visibleWidth);
            }
            final viewStart = effectiveStart;
            final viewEnd = effectiveStart + visibleWidth;

            return LayoutBuilder(
              builder: (ctx, c) => MouseRegion(
                cursor: SystemMouseCursors.basic,
                onExit: (_) => setState(() => _hoverX = null),
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: (e) {
                    if (e is! PointerScrollEvent) return;
                    final keys = HardwareKeyboard.instance;
                    final zoomMod = keys.isMetaPressed ||
                                    keys.isControlPressed;
                    if (zoomMod) {
                      // Cmd / Ctrl + wheel → zoom anchored at the
                      // cursor. Throttle so a single trackpad swipe
                      // doesn't slingshot through every zoom level.
                      final now = DateTime.now();
                      if (now.difference(_lastWheelZoomAt) <
                          _wheelZoomCooldown) {
                        return;
                      }
                      // Up / forward (negative dy) zooms IN, down /
                      // back zooms OUT — matches Reaper / Logic.
                      final dy = e.scrollDelta.dy;
                      if (dy.abs() < 0.5) return;
                      _zoomAtMouse(
                        e.localPosition.dx,
                        c.maxWidth,
                        dy < 0 ? 1 : -1,
                        viewStart,
                        viewEnd,
                      );
                      return;
                    }
                    // No modifier → horizontal pan. Either axis maps
                    // to pan: most trackpads emit dx for two-finger
                    // horizontal and dy for vertical; mouse wheel
                    // emits dy.
                    final delta =
                        e.scrollDelta.dx.abs() > e.scrollDelta.dy.abs()
                            ? e.scrollDelta.dx
                            : e.scrollDelta.dy;
                    if (delta != 0) {
                      _pan(delta, c.maxWidth, visibleWidth);
                    }
                  },
                  onPointerHover: (e) =>
                      setState(() => _hoverX = e.localPosition.dx),
                  onPointerDown: (e) {
                    setState(() => _hoverX = e.localPosition.dx);
                    _seekToX(
                      player,
                      e.localPosition.dx,
                      c.maxWidth,
                      dur,
                      viewStart,
                      viewEnd,
                    );
                  },
                  onPointerMove: (e) {
                    setState(() => _hoverX = e.localPosition.dx);
                    if (e.buttons != 0) {
                      _seekToX(
                        player,
                        e.localPosition.dx,
                        c.maxWidth,
                        dur,
                        viewStart,
                        viewEnd,
                      );
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 18,
                        child: CustomPaint(
                          painter: _RulerPainter(
                            duration: dur,
                            viewStart: viewStart,
                            viewEnd: viewEnd,
                          ),
                        ),
                      ),
                      Container(
                        height: ConsoleSkin.hairlinePx,
                        color: ConsoleSkin.hairline,
                      ),
                      Expanded(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _WaveformPainter(
                              wave: wave,
                              pos: pos,
                              dur: dur,
                              viewStart: viewStart,
                              viewEnd: viewEnd,
                              hoverX: _hoverX,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Ruler ────────────────────────────────────────────────────────────

class _RulerPainter extends CustomPainter {
  final Duration duration;
  final double viewStart;
  final double viewEnd;

  _RulerPainter({
    required this.duration,
    required this.viewStart,
    required this.viewEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    final totalSecs = duration.inMilliseconds / 1000.0;
    if (totalSecs <= 0 || size.width <= 0) return;

    final visibleSecs = (viewEnd - viewStart) * totalSecs;
    if (visibleSecs <= 0) return;

    // Pick a "nice" major-tick interval based on what's visible. Keeps
    // the label density roughly constant from full-track zoom 1 down
    // to per-second zoom levels.
    final majorSecs = _niceMajorInterval(visibleSecs);
    final minorSecs = majorSecs / 5;

    final viewStartSec = viewStart * totalSecs;
    final viewEndSec = viewEnd * totalSecs;
    final pxPerSec = size.width / visibleSecs;

    final majorPaint = Paint()
      ..color = ConsoleSkin.fgDim
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = false;
    final minorPaint = Paint()
      ..color = ConsoleSkin.fgFaint
      ..strokeWidth = ConsoleSkin.hairlinePx
      ..isAntiAlias = false;

    // Minor ticks first, then majors over the top.
    var minor = (viewStartSec / minorSecs).ceil() * minorSecs;
    while (minor <= viewEndSec) {
      final x = ((minor - viewStartSec) * pxPerSec).floorToDouble() + 0.5;
      hairline(
        canvas,
        Offset(x, size.height - 4),
        Offset(x, size.height),
        color: minorPaint.color,
      );
      minor += minorSecs;
    }

    var major = (viewStartSec / majorSecs).ceil() * majorSecs;
    while (major <= viewEndSec) {
      final x = ((major - viewStartSec) * pxPerSec).floorToDouble() + 0.5;
      hairline(
        canvas,
        Offset(x, size.height - 8),
        Offset(x, size.height),
        color: majorPaint.color,
      );
      // Label CENTRED horizontally on the major tick, top-aligned a
      // few pixels below the ruler top. Edge-clamped so the first /
      // last labels don't bleed past the canvas — keeps the ruler
      // strip readable at every zoom level.
      final label = _formatTime(major, majorSecs);
      final labelSize = Glyph.measure(
        label,
        size: 9,
        mono: true,
      );
      var dx = x - labelSize.width / 2;
      if (dx < 1) dx = 1;
      if (dx + labelSize.width > size.width - 1) {
        dx = size.width - 1 - labelSize.width;
      }
      Glyph.draw(
        canvas,
        label,
        offset: Offset(dx, 1),
        size: 9,
        color: ConsoleSkin.fgDim,
        mono: true,
      );
      major += majorSecs;
    }
  }

  /// Returns a "nice" major-tick interval (in seconds) that keeps
  /// roughly 6-12 ticks across the visible window. The progression
  /// follows the standard 1-2-5-10 series scaled by powers of 60 for
  /// minutes / hours.
  static double _niceMajorInterval(double visibleSecs) {
    const candidates = <double>[
      0.1, 0.2, 0.5,             // sub-second
      1, 2, 5,                    // seconds
      10, 30,                      // tens of seconds
      60, 120, 300,                // minutes
      600, 1800,                   // tens of minutes
      3600, 7200,                  // hours
    ];
    final target = visibleSecs / 8;        // aim for ~8 majors visible
    for (final c in candidates) {
      if (c >= target) return c;
    }
    return candidates.last;
  }

  static String _formatTime(double secs, double interval) {
    if (secs < 60) {
      // Sub-minute: show seconds (or fractions if zoomed in tight).
      if (interval < 1) return secs.toStringAsFixed(1);
      return '${secs.round()}s';
    }
    if (secs < 3600) {
      final m = (secs / 60).floor();
      final s = (secs % 60).round();
      if (interval >= 60) return '${m}m';
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    final h = (secs / 3600).floor();
    final m = ((secs % 3600) / 60).round();
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.duration != duration ||
      old.viewStart != viewStart ||
      old.viewEnd != viewEnd;
}

// ─── Waveform body ────────────────────────────────────────────────────

class _WaveformPainter extends CustomPainter {
  final WaveformData? wave;
  final Duration pos;
  final Duration dur;
  final double viewStart;
  final double viewEnd;
  final double? hoverX;

  _WaveformPainter({
    required this.wave,
    required this.pos,
    required this.dur,
    required this.viewStart,
    required this.viewEnd,
    required this.hoverX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ConsoleSkin.bgDeep);

    final cy = size.height / 2;
    // Peak amplitude of 1.0 reaches the canvas edges directly — the
    // wave fills the strip top to bottom.
    final ampY = cy;

    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = ConsoleSkin.fgFaint
        ..strokeWidth = ConsoleSkin.hairlinePx,
    );

    final w = wave;
    if (w != null && w.bins > 0 && size.width > 0) {
      final bins = w.bins;
      var startBin = (viewStart * bins).floor();
      var endBin = (viewEnd * bins).ceil();
      if (startBin < 0) startBin = 0;
      if (endBin > bins) endBin = bins;
      final visibleBins = endBin - startBin;
      if (visibleBins <= 0) return;

      final pxPerBin = size.width / visibleBins;
      final binPerPx = visibleBins / size.width;

      final played = dur.inMilliseconds > 0
          ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      final viewWidth = (viewEnd - viewStart);
      final playedX = viewWidth > 0
          ? size.width * ((played - viewStart) / viewWidth).clamp(0.0, 1.0)
          : 0.0;

      final paintPlayed = Paint()
        ..color = ConsoleSkin.accent
        ..strokeCap = StrokeCap.butt;
      final paintFuture = Paint()
        ..color = ConsoleSkin.fgDim
        ..strokeCap = StrokeCap.butt;

      if (binPerPx >= 1.0) {
        final cols = size.width.ceil();
        for (var col = 0; col < cols; col++) {
          final bStart = startBin + (col * binPerPx).floor();
          final bEnd =
              (startBin + ((col + 1) * binPerPx).ceil()).clamp(0, endBin);
          var mn = 0.0;
          var mx = 0.0;
          for (var i = bStart; i < bEnd; i++) {
            final bMn = w.min[i];
            final bMx = w.max[i];
            if (bMn < mn) mn = bMn;
            if (bMx > mx) mx = bMx;
          }
          final x = col + 0.5;
          final paint = x <= playedX ? paintPlayed : paintFuture;
          paint.strokeWidth = 1;
          canvas.drawLine(
            Offset(x, cy - mx.clamp(-1.0, 1.0) * ampY),
            Offset(x, cy - mn.clamp(-1.0, 1.0) * ampY),
            paint,
          );
        }
      } else {
        final colW = pxPerBin;
        final stroke = colW < 2 ? 1.0 : colW * 0.7;
        for (var i = startBin; i < endBin; i++) {
          final localCol = i - startBin;
          final x = localCol * colW + colW / 2;
          final mn = w.min[i].clamp(-1.0, 1.0);
          final mx = w.max[i].clamp(-1.0, 1.0);
          final paint = x <= playedX ? paintPlayed : paintFuture;
          paint.strokeWidth = stroke;
          canvas.drawLine(
            Offset(x, cy - mx * ampY),
            Offset(x, cy - mn * ampY),
            paint,
          );
        }
      }
    }

    // Hover preview cursor — bright neutral so it reads on top of
    // the dark waveform background and the dim grey "future" columns
    // alike. Drawn BEFORE the playhead so the accent playhead always
    // wins when they overlap.
    final hx = hoverX;
    if (hx != null && hx >= 0 && hx <= size.width) {
      canvas.drawLine(
        Offset(hx, 0),
        Offset(hx, size.height),
        Paint()
          ..color = ConsoleSkin.fg
          ..strokeWidth = 1.5,
      );
    }

    // Playhead cursor.
    if (dur.inMilliseconds > 0) {
      final played =
          (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
      final viewWidth = (viewEnd - viewStart);
      if (viewWidth > 0 && played >= viewStart && played <= viewEnd) {
        final x = size.width * (played - viewStart) / viewWidth;
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, size.height),
          Paint()
            ..color = ConsoleSkin.accentHot
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      !identical(old.wave, wave) ||
      old.pos != pos ||
      old.dur != dur ||
      old.viewStart != viewStart ||
      old.viewEnd != viewEnd ||
      old.hoverX != hoverX;
}
