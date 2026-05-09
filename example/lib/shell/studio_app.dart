import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_button.dart';
import '../atoms/atom_label.dart';
import '../atoms/atom_menu_bar.dart';
import '../console/console_controller.dart';
import '../console/console_panel.dart';
import '../inspector/inspector_panel.dart';
import '../library/library_panel.dart';
import '../preferences/preferences_overlay.dart';
import '../rack/filter_catalog.dart';
import '../rack/rack.dart';
import '../skin/console_skin.dart';
import '../stage/stage.dart';
import '../stage/transport_strip.dart';
import 'breakpoints.dart';
import 'studio_scope.dart';

/// Root of the example. WidgetsApp (not MaterialApp / CupertinoApp), so
/// the framework provides MediaQuery / Directionality / Localizations
/// without forcing any opinionated chrome on us.
class StudioApp extends StatelessWidget {
  final Player player;
  const StudioApp({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return StudioScope(
      player: player,
      child: WidgetsApp(
        title: 'mpv_audio_kit',
        color: ConsoleSkin.accent,
        debugShowCheckedModeBanner: false,
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (ctx, _, _) => builder(ctx),
        ),
        builder: (ctx, child) => DefaultTextStyle(
          style: const TextStyle(
            color: ConsoleSkin.fg,
            fontSize: ConsoleSkin.sizeBody,
            fontFamily: ConsoleSkin.fontUI,
          ),
          child: ColoredBox(
            color: ConsoleSkin.bg,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: const _StudioRoot(),
      ),
    );
  }
}

class _StudioRoot extends StatefulWidget {
  const _StudioRoot();

  @override
  State<_StudioRoot> createState() => _StudioRootState();
}

class _StudioRootState extends State<_StudioRoot> {
  bool _dragOver = false;
  bool _prefsOpen = false;
  bool _showLibrary = true;
  bool _showInspector = true;
  bool _showRack = true;
  bool _showConsole = true;
  // Console panel — height is user-resizable; the controller is
  // hoisted out of the panel so toggling visibility does not drop
  // the buffer.
  double _consoleHeight = 160;
  static const double _consoleMin = 80;
  static const double _consoleMax = 600;
  ConsoleController? _console;
  // Sidebar sizes — volatile, reset on app restart.
  double _libraryWidth = 220;
  double _inspectorWidth = 260;
  // Rack height is owned by [_DesktopLayout] now: it watches the live
  // filter count and caps the resize at the actual content height
  // (one row per chip-row, no empty padding below). The shell stays
  // out of that math.
  // Waveform horizontal zoom. 1 = entire track visible; 2 = half;
  // 4 = quarter; etc. Centered on the playhead.
  int _waveformZoom = 1;
  static const int _zoomMin = 1;
  static const int _zoomMax = 16;

  void _zoomIn() {
    if (_waveformZoom >= _zoomMax) return;
    setState(() => _waveformZoom = (_waveformZoom * 2).clamp(_zoomMin, _zoomMax));
  }

  void _zoomOut() {
    if (_waveformZoom <= _zoomMin) return;
    setState(() => _waveformZoom = (_waveformZoom ~/ 2).clamp(_zoomMin, _zoomMax));
  }

  void _zoomReset() {
    if (_waveformZoom == 1) return;
    setState(() => _waveformZoom = 1);
  }

  static const double _libraryMin = 160;
  static const double _libraryMax = 400;
  static const double _inspectorMin = 200;
  static const double _inspectorMax = 420;

  void _resizeLibrary(double dx) {
    setState(() {
      _libraryWidth =
          (_libraryWidth + dx).clamp(_libraryMin, _libraryMax);
    });
  }

  void _resizeInspector(double dx) {
    setState(() {
      _inspectorWidth =
          (_inspectorWidth - dx).clamp(_inspectorMin, _inspectorMax);
    });
  }

  Future<void> _handleDrop(List<String> paths) async {
    final player = StudioScope.of(context);
    await appendOrOpenAll(player, paths);
  }

  void _resizeConsole(double dy) {
    setState(() {
      _consoleHeight =
          (_consoleHeight - dy).clamp(_consoleMin, _consoleMax);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lazy-attach the console controller on first build so it can
    // pick up the player from [StudioScope]. Subscribing eagerly
    // means the buffer is populated even if the user never opens
    // the console panel.
    _console ??= ConsoleController()..attach(StudioScope.of(context));
  }

  @override
  void dispose() {
    _console?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        _TopMenuBar(
          onOpenFile: () => pickAndAppendFiles(StudioScope.of(context)),
          onClearLibrary: () => StudioScope.of(context).clearPlaylist(),
          onOpenPrefs: () => setState(() => _prefsOpen = true),
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onZoomReset: _zoomReset,
          zoomLevel: _waveformZoom,
          zoomMax: _zoomMax,
          zoomMin: _zoomMin,
          showLibrary: _showLibrary,
          showInspector: _showInspector,
          showRack: _showRack,
          showConsole: _showConsole,
          onToggleLibrary:
              () => setState(() => _showLibrary = !_showLibrary),
          onToggleInspector:
              () => setState(() => _showInspector = !_showInspector),
          onToggleRack: () => setState(() => _showRack = !_showRack),
          onToggleConsole:
              () => setState(() => _showConsole = !_showConsole),
        ),
        const _Hairline(),
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) {
              final w = c.maxWidth;
              if (Breakpoints.isDesktop(w)) {
                return _DesktopLayout(
                  showLibrary: _showLibrary,
                  showInspector: _showInspector,
                  showRack: _showRack,
                  libraryWidth: _libraryWidth,
                  inspectorWidth: _inspectorWidth,
                  zoomLevel: _waveformZoom,
                  zoomMin: _zoomMin,
                  zoomMax: _zoomMax,
                  onZoomChanged: (z) =>
                      setState(() => _waveformZoom = z),
                  onResizeLibrary: _resizeLibrary,
                  onResizeInspector: _resizeInspector,
                );
              }
              if (Breakpoints.isTablet(w)) {
                return _TabletLayout(zoomLevel: _waveformZoom);
              }
              return _PhoneLayout(zoomLevel: _waveformZoom);
            },
          ),
        ),
        if (_showConsole) ...[
          _HSplitter(onDrag: _resizeConsole),
          SizedBox(
            height: _consoleHeight,
            child: ConsolePanel(controller: _console!),
          ),
        ],
      ],
    );

    final supportsDrop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final main = supportsDrop
        ? DropTarget(
            onDragEntered: (_) => setState(() => _dragOver = true),
            onDragExited:  (_) => setState(() => _dragOver = false),
            onDragDone: (detail) {
              setState(() => _dragOver = false);
              _handleDrop(detail.files.map((f) => f.path).toList());
            },
            child: Stack(
              children: [
                body,
                if (_dragOver)
                  const Positioned.fill(child: _DropOverlay()),
              ],
            ),
          )
        : body;

    return Stack(
      children: [
        main,
        if (_prefsOpen)
          Positioned.fill(
            child: PreferencesOverlay(
              onClose: () => setState(() => _prefsOpen = false),
            ),
          ),
      ],
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0xCC0E1E2E),
      child: Center(
        child: AtomLabel(
          'DROP TO PLAY',
          fontSize: ConsoleSkin.sizeH1,
          color: ConsoleSkin.accentHot,
          mono: true,
          letterSpacing: 4,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Layouts ────────────────────────────────────────────────────────────

class _DesktopLayout extends StatefulWidget {
  final bool showLibrary;
  final bool showInspector;
  final bool showRack;
  final double libraryWidth;
  final double inspectorWidth;
  final int zoomLevel;
  final int zoomMin;
  final int zoomMax;
  final ValueChanged<int> onZoomChanged;
  final ValueChanged<double> onResizeLibrary;
  final ValueChanged<double> onResizeInspector;

  const _DesktopLayout({
    required this.showLibrary,
    required this.showInspector,
    required this.showRack,
    required this.libraryWidth,
    required this.inspectorWidth,
    required this.zoomLevel,
    required this.zoomMin,
    required this.zoomMax,
    required this.onZoomChanged,
    required this.onResizeLibrary,
    required this.onResizeInspector,
  });

  @override
  State<_DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<_DesktopLayout> {
  // Extra height the user has dragged ABOVE the live content height.
  // The rack always anchors at "exactly fits the present filter
  // rows" and grows from there: dragging the splitter up pushes
  // [_extraAboveFloor] up (stealing space from the stage), dragging
  // down brings it back to zero (rack snaps to "all filters
  // visible, no padding"). Adding / removing filters changes the
  // floor live; the extra rides on top of it, so the user-perceived
  // padding is preserved across filter edits and the rack still
  // auto-shrinks when filters get removed.
  double _extraAboveFloor = 0;

  // Geometry constants — kept here because they're the only place that
  // converts "N filters at width W" into pixels, and they must stay
  // in sync with [FxChip] (height + margin) and [Rack._Header] (28px
  // + 1px hairline + 8px top padding).
  static const double _rackHeader     = 29;   // header + hairline
  static const double _rackPadTop     =  8;
  static const double _rackChipHeight = 32;   // FxChip 26 + 6 margin
  static const double _rackChipWidth  = 130;  // average chip width
  static const double _rackOneRow =
      _rackHeader + _rackPadTop + _rackChipHeight;
  static const double _rackHardMax = 400;     // upper cap on grow

  /// Computes the natural rack height for [chipCount] chips at the
  /// current [width]. Chips wrap inside a [Wrap], so the row count is
  /// `ceil(N / floor(W / avgChipWidth))`. The empty case still yields
  /// one row so the rack never collapses below "one chip's worth of
  /// room". Approximation — chip widths vary with filter name length,
  /// but the ~130 px average is close enough for the rack to look
  /// content-fitted rather than empty-padded.
  static double _contentHeight(int chipCount, double width) {
    if (width <= 0) return _rackOneRow;
    final perRow = (width / _rackChipWidth).floor().clamp(1, 999);
    final rows = chipCount <= 0
        ? 1
        : ((chipCount + perRow - 1) ~/ perRow);
    return _rackHeader + _rackPadTop + rows * _rackChipHeight;
  }

  void _onResizeRack(double dy, double floor) {
    setState(() {
      // dy > 0 (drag down) → shrink the extra padding; dy < 0
      // (drag up) → grow it. Capped between 0 (snapped to floor)
      // and the headroom remaining up to [_rackHardMax].
      final headroom =
          (_rackHardMax - floor).clamp(0.0, _rackHardMax);
      _extraAboveFloor =
          (_extraAboveFloor - dy).clamp(0.0, headroom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = StudioScope.of(context);
    return Row(
      children: [
        if (widget.showLibrary) ...[
          SizedBox(width: widget.libraryWidth, child: const LibraryPanel()),
          _VSplitter(onDrag: widget.onResizeLibrary),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, c) => StreamBuilder<AudioEffects>(
              stream: player.stream.audioEffects,
              initialData: player.state.audioEffects,
              builder: (ctx, snap) {
                final bundle = snap.data ?? const AudioEffects();
                final activeCount =
                    filterCatalog.where((f) => f.isOn(bundle)).length;
                final floorRack = _contentHeight(activeCount, c.maxWidth);
                final effective =
                    (floorRack + _extraAboveFloor).clamp(
                  floorRack,
                  _rackHardMax,
                );
                return Column(
                  children: [
                    // Stage = header + waveform; the waveform takes
                    // every pixel left over after the bottom panel
                    // grabs its share.
                    Expanded(
                      key: const ValueKey('stage'),
                      child: Stage(
                        zoomLevel: widget.zoomLevel,
                        zoomMin: widget.zoomMin,
                        zoomMax: widget.zoomMax,
                        onZoomChanged: widget.onZoomChanged,
                      ),
                    ),
                    // Stable keys are load-bearing here: toggling
                    // the rack changes the children-list length,
                    // and without keys Flutter would match by index
                    // and unmount the [TransportStrip] every time
                    // (resetting its spectrum animation, cover art,
                    // hover state, …). With keys, each child's
                    // element survives the reorder.
                    if (widget.showRack)
                      _HSplitter(
                        key: const ValueKey('rack-splitter'),
                        onDrag: (dy) => _onResizeRack(dy, floorRack),
                      ),
                    const TransportStrip(
                      key: ValueKey('transport-strip'),
                    ),
                    if (widget.showRack) ...[
                      const _Hairline(key: ValueKey('rack-hairline')),
                      SizedBox(
                        key: const ValueKey('rack-box'),
                        height: effective,
                        child: const Rack(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
        if (widget.showInspector) ...[
          _VSplitter(onDrag: widget.onResizeInspector),
          SizedBox(
              width: widget.inspectorWidth, child: const InspectorPanel()),
        ],
      ],
    );
  }
}

class _TabletLayout extends StatelessWidget {
  final int zoomLevel;
  const _TabletLayout({required this.zoomLevel});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(flex: 3, child: Stage(zoomLevel: zoomLevel)),
        const _Hairline(),
        const Expanded(
          flex: 2,
          child: _PanelStub(label: 'LIBRARY · RACK · INSPECTOR'),
        ),
      ],
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  final int zoomLevel;
  const _PhoneLayout({required this.zoomLevel});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Stage(zoomLevel: zoomLevel)),
        const _Hairline(),
        const SizedBox(
          height: 120,
          child: _PanelStub(label: 'LIBRARY  ·  FX  ·  I/O'),
        ),
      ],
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────

class _TopMenuBar extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onClearLibrary;
  final VoidCallback onOpenPrefs;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomReset;
  final int zoomLevel;
  final int zoomMin;
  final int zoomMax;
  final bool showLibrary;
  final bool showInspector;
  final bool showRack;
  final bool showConsole;
  final VoidCallback onToggleLibrary;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleRack;
  final VoidCallback onToggleConsole;

  const _TopMenuBar({
    required this.onOpenFile,
    required this.onClearLibrary,
    required this.onOpenPrefs,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.zoomLevel,
    required this.zoomMin,
    required this.zoomMax,
    required this.showLibrary,
    required this.showInspector,
    required this.showRack,
    required this.showConsole,
    required this.onToggleLibrary,
    required this.onToggleInspector,
    required this.onToggleRack,
    required this.onToggleConsole,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        // Asymmetric: no left padding so the first menu's button
        // (and therefore its popover) sits flush against the window
        // left edge. The right side keeps 4 so the panel-toggle
        // buttons mirror the library / inspector panel headers'
        // right-side internal padding.
        padding: const EdgeInsets.only(right: 4),
        child: Row(
          // Stretch so child widgets that want to fill the topbar
          // height (the menu labels — for popover anchoring) get a
          // tight 28-tall constraint.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MenuBar(
              menus: [
                MenuPullDown(
                  label: 'File',
                  items: [
                    MenuAction(
                      label: 'Open',
                      shortcutHint: '⌘O',
                      onTap: onOpenFile,
                    ),
                    const MenuDivider(),
                    MenuAction(
                      label: 'Clear',
                      onTap: onClearLibrary,
                    ),
                  ],
                ),
                MenuPullDown(
                  label: 'Edit',
                  items: [
                    MenuAction(
                      label: 'Preferences',
                      shortcutHint: '⌘,',
                      onTap: onOpenPrefs,
                    ),
                  ],
                ),
                MenuPullDown(
                  label: 'View',
                  items: [
                    MenuAction(
                      label: 'Zoom In',
                      shortcutHint: '⌘+',
                      enabled: zoomLevel < zoomMax,
                      onTap: onZoomIn,
                    ),
                    MenuAction(
                      label: 'Zoom Out',
                      shortcutHint: '⌘−',
                      enabled: zoomLevel > zoomMin,
                      onTap: onZoomOut,
                    ),
                    MenuAction(
                      label: 'Actual Size',
                      shortcutHint: '⌘0',
                      enabled: zoomLevel != zoomMin,
                      onTap: onZoomReset,
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            AtomButton(
              label: 'panel-left',
              icon: IconGlyph.panelLeft,
              iconActive: showLibrary,
              flat: true,
              onTap: onToggleLibrary,
              width: 20,
              height: 20,
            ),
            AtomButton(
              label: 'panel-bottom-fx',
              icon: IconGlyph.panelBottomFx,
              iconActive: showRack,
              flat: true,
              onTap: onToggleRack,
              width: 20,
              height: 20,
            ),
            AtomButton(
              label: 'panel-bottom-console',
              icon: IconGlyph.panelBottomConsole,
              iconActive: showConsole,
              flat: true,
              onTap: onToggleConsole,
              width: 20,
              height: 20,
            ),
            AtomButton(
              label: 'panel-right',
              icon: IconGlyph.panelRight,
              iconActive: showInspector,
              flat: true,
              onTap: onToggleInspector,
              width: 20,
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelStub extends StatelessWidget {
  final String label;
  const _PanelStub({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bg,
      child: Center(
        child: AtomLabel(
          label,
          fontSize: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgFaint,
          mono: true,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline({super.key});
  @override
  Widget build(BuildContext context) =>
      Container(height: ConsoleSkin.hairlinePx, color: ConsoleSkin.hairline);
}

/// Vertical drag splitter — 4 px hit area with the 1 px visible hairline
/// centred. Hover changes the cursor and tints the line accent.
class _VSplitter extends StatefulWidget {
  final ValueChanged<double> onDrag;
  const _VSplitter({required this.onDrag});
  @override
  State<_VSplitter> createState() => _VSplitterState();
}

class _VSplitterState extends State<_VSplitter> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
        child: SizedBox(
          width: 4,
          child: Center(
            child: Container(
              width: ConsoleSkin.hairlinePx,
              color: _hot ? ConsoleSkin.accent : ConsoleSkin.hairline,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal drag splitter — same idea as [_VSplitter] but resizes a
/// row above / below instead of a column left / right.
class _HSplitter extends StatefulWidget {
  final ValueChanged<double> onDrag;
  const _HSplitter({super.key, required this.onDrag});
  @override
  State<_HSplitter> createState() => _HSplitterState();
}

class _HSplitterState extends State<_HSplitter> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hot = true),
      onExit: (_) => setState(() => _hot = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => widget.onDrag(d.delta.dy),
        child: SizedBox(
          height: 4,
          child: Center(
            child: Container(
              height: ConsoleSkin.hairlinePx,
              color: _hot ? ConsoleSkin.accent : ConsoleSkin.hairline,
            ),
          ),
        ),
      ),
    );
  }
}
