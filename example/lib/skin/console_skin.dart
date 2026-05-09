import 'dart:ui';

/// Single source of truth for the console look. Changing skin = changing
/// values here. No widget reads colours from the framework — every atom
/// pulls from this struct.
class ConsoleSkin {
  // ── Surfaces ─────────────────────────────────────────────────────────
  static const Color bg        = Color(0xFF1A1A1A);
  static const Color bgRaised  = Color(0xFF232323);
  static const Color bgDeep    = Color(0xFF111111);
  static const Color hairline  = Color(0xFF2E2E2E);

  // ── Text / foreground ───────────────────────────────────────────────
  static const Color fg        = Color(0xFFC8C8C8);
  static const Color fgDim     = Color(0xFF7D7D7D);
  static const Color fgFaint   = Color(0xFF4A4A4A);

  // ── Accent (blue, dark-tuned — Material Blue desaturates well on #1A1A1A) ──
  static const Color accent    = Color(0xFF4EA3FF);
  static const Color accentHot = Color(0xFF7AB7FF);
  static const Color accentDim = Color(0xFF2A6DB0);

  // ── Meter / status ──────────────────────────────────────────────────
  static const Color meterGreen = Color(0xFF29C46A);
  static const Color meterAmber = Color(0xFFF5B400);
  static const Color meterRed   = Color(0xFFE84545);
  static const Color meterCyan  = Color(0xFF2EC4B6);   // teal — INFO log level

  // ── Per-band palette ───────────────────────────────────────────────
  // Eight evenly-spaced hues at consistent saturation / luminance,
  // used to distinguish individual elements in multi-element editors
  // (anequalizer bands, mcompand bands, aecho taps, chorus voices).
  // Pick by `bandPalette[i % bandPalette.length]`. Reference: Pro-Q 4
  // / Pro-MB give each band a distinct hue so the user can map a
  // control row entry back to its visualisation at a glance.
  static const List<Color> bandPalette = <Color>[
    Color(0xFF4EA3FF), // accent (blue)
    Color(0xFF29C46A), // green
    Color(0xFFF5B400), // amber
    Color(0xFFE84545), // red
    Color(0xFF2EC4B6), // teal
    Color(0xFFB877FF), // violet
    Color(0xFFFF7E45), // orange
    Color(0xFFE860B0), // pink
  ];

  // ── Fonts ────────────────────────────────────────────────────────────
  // System fallback for now: real Inter / JetBrainsMono can be added as
  // assets later without touching call sites — Glyph reads from here.
  static const String? fontUI   = null;        // platform default sans
  static const String  fontMono = 'Menlo';     // SF Mono on Apple, fallback elsewhere

  // ── Sizes ────────────────────────────────────────────────────────────
  static const double sizeTiny  = 10;
  static const double sizeSmall = 11;
  static const double sizeBody  = 12;
  static const double sizeH1    = 14;

  // ── Metrics ──────────────────────────────────────────────────────────
  static const double row      = 24;
  static const double gap      =  6;
  static const double pad      =  8;
  static const double radius   =  2;
  static const double hairlinePx = 1;
}
