import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_button.dart';
import '../atoms/atom_label.dart';
import '../atoms/atom_menu_bar.dart';
import '../inspector/inspector_panel.dart';
import '../library/library_panel.dart';
import '../preferences/preferences_overlay.dart';
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
  // Sidebar sizes — volatile, reset on app restart.
  double _libraryWidth = 220;
  double _inspectorWidth = 260;
  double _rackHeight = 130;
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
  static const double _rackMin = 80;
  static const double _rackMax = 400;

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

  void _resizeRack(double dy) {
    setState(() {
      _rackHeight = (_rackHeight - dy).clamp(_rackMin, _rackMax);
    });
  }

  Future<void> _handleDrop(List<String> paths) async {
    final player = StudioScope.of(context);
    await appendOrOpenAll(player, paths);
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
          onToggleLibrary:
              () => setState(() => _showLibrary = !_showLibrary),
          onToggleInspector:
              () => setState(() => _showInspector = !_showInspector),
          onToggleRack: () => setState(() => _showRack = !_showRack),
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
                  rackHeight: _rackHeight,
                  zoomLevel: _waveformZoom,
                  onResizeLibrary: _resizeLibrary,
                  onResizeInspector: _resizeInspector,
                  onResizeRack: _resizeRack,
                );
              }
              if (Breakpoints.isTablet(w)) {
                return _TabletLayout(zoomLevel: _waveformZoom);
              }
              return _PhoneLayout(zoomLevel: _waveformZoom);
            },
          ),
        ),
        const _Hairline(),
        const _Console(),
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

class _DesktopLayout extends StatelessWidget {
  final bool showLibrary;
  final bool showInspector;
  final bool showRack;
  final double libraryWidth;
  final double inspectorWidth;
  final double rackHeight;
  final int zoomLevel;
  final ValueChanged<double> onResizeLibrary;
  final ValueChanged<double> onResizeInspector;
  final ValueChanged<double> onResizeRack;

  const _DesktopLayout({
    required this.showLibrary,
    required this.showInspector,
    required this.showRack,
    required this.libraryWidth,
    required this.inspectorWidth,
    required this.rackHeight,
    required this.zoomLevel,
    required this.onResizeLibrary,
    required this.onResizeInspector,
    required this.onResizeRack,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showLibrary) ...[
          SizedBox(width: libraryWidth, child: const LibraryPanel()),
          _VSplitter(onDrag: onResizeLibrary),
        ],
        Expanded(
          child: Column(
            children: [
              // Stage = header + waveform; the waveform takes every
              // pixel left over after the bottom panel grabs its share.
              Expanded(child: Stage(zoomLevel: zoomLevel)),
              // Drag handle sits ABOVE the transport strip so the
              // resizable unit is visually "the bottom panel" — both
              // transport and rack move together when the user drags.
              // We only render the splitter when the rack is visible:
              // with the rack hidden the bottom panel is just the
              // fixed-height transport, nothing to resize.
              if (showRack) _HSplitter(onDrag: onResizeRack),
              const TransportStrip(),
              if (showRack) ...[
                const _Hairline(),
                SizedBox(height: rackHeight, child: const Rack()),
              ],
            ],
          ),
        ),
        if (showInspector) ...[
          _VSplitter(onDrag: onResizeInspector),
          SizedBox(width: inspectorWidth, child: const InspectorPanel()),
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
  final VoidCallback onToggleLibrary;
  final VoidCallback onToggleInspector;
  final VoidCallback onToggleRack;

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
    required this.onToggleLibrary,
    required this.onToggleInspector,
    required this.onToggleRack,
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
              label: 'panel-bottom',
              icon: IconGlyph.panelBottom,
              iconActive: showRack,
              flat: true,
              onTap: onToggleRack,
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

class _Console extends StatelessWidget {
  const _Console();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel('▸ console',
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgDim,
                  mono: true),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel('TODO — log strip lands in Phase 4',
                  fontSize: ConsoleSkin.sizeTiny,
                  color: ConsoleSkin.fgFaint,
                  mono: true),
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
  const _Hairline();
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
  const _HSplitter({required this.onDrag});
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
