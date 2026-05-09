import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_label.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import '../skin/glyph.dart';
import '../skin/paint_helpers.dart';

/// Filesystem browser sidebar. Replaces the old playlist queue: click a
/// folder to navigate into it, click an audio file to play it (single-
/// track replace via [Player.open]). The breadcrumb at the top lets
/// you jump back to any ancestor in one click; [↑] climbs one level,
/// [⌂] returns to the initial directory.
///
/// Drag-drop and the topbar OPEN button still go through
/// [pickAndAppendFiles] / [appendOrOpenAll] (kept here for backward
/// compat) and may build a multi-item queue when more than one file
/// is selected at once. Click-to-play from the browser is always
/// single-track replace.
class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  late Directory _dir;

  @override
  void initState() {
    super.initState();
    _dir = _initialDir();
  }

  /// Best initial location across platforms — the user's Music folder
  /// when it exists, otherwise the home directory, otherwise the
  /// filesystem root. Synchronous; called once from [initState].
  static Directory _initialDir() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '/';
    for (final candidate in [
      '$home${Platform.pathSeparator}Music',
      home,
    ]) {
      final d = Directory(candidate);
      if (d.existsSync()) return d;
    }
    return Directory(Platform.pathSeparator);
  }

  void _navigate(Directory next) => setState(() => _dir = next);

  void _goUp() {
    final p = _dir.parent;
    if (p.path != _dir.path) _navigate(p);
  }

  void _goHome() => _navigate(_initialDir());

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(onUp: _goUp, onHome: _goHome),
        const _Hairline(),
        _Breadcrumb(dir: _dir, onJump: _navigate),
        const _Hairline(),
        Expanded(child: _Listing(dir: _dir, onNavigate: _navigate)),
      ],
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onHome;
  const _Header({required this.onUp, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel(
                'LIBRARY',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.accent,
                mono: true,
                letterSpacing: 1.5,
                weight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _NavButton(label: '⌂', onTap: onHome, tooltip: 'home'),
            _NavButton(label: '↑', onTap: onUp, tooltip: 'parent'),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final String tooltip;
  const _NavButton({
    required this.label,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 22,
          height: 22,
          child: Center(
            child: AtomLabel(
              widget.label,
              fontSize: ConsoleSkin.sizeBody,
              color: _hover ? ConsoleSkin.fg : ConsoleSkin.fgDim,
              mono: true,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Breadcrumb ────────────────────────────────────────────────────────

class _Breadcrumb extends StatelessWidget {
  final Directory dir;
  final ValueChanged<Directory> onJump;
  const _Breadcrumb({required this.dir, required this.onJump});

  @override
  Widget build(BuildContext context) {
    final segments = _segments(dir);
    return SizedBox(
      height: 22,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,           // keep the deepest segment visible
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: AtomLabel(
                    '/',
                    fontSize: ConsoleSkin.sizeTiny,
                    color: ConsoleSkin.fgFaint,
                    mono: true,
                  ),
                ),
              _CrumbSegment(
                label: segments[i].$1,
                onTap: () => onJump(segments[i].$2),
                isLast: i == segments.length - 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Walk from the filesystem root down to [dir], yielding
  /// `(displayName, Directory)` for every segment. The first segment
  /// renders as `⌂` when it matches the user's home directory, so the
  /// crumb stays compact for the common case (`~/Music/Avicii/...`).
  static List<(String, Directory)> _segments(Directory dir) {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    final out = <(String, Directory)>[];
    var d = dir;
    while (true) {
      final parent = d.parent;
      final name = d.path == parent.path
          ? d.path                    // root reached
          : d.path.split(Platform.pathSeparator).last;
      out.insert(0, (name.isEmpty ? '/' : name, d));
      if (d.path == parent.path) break;
      d = parent;
    }
    if (home != null) {
      for (var i = 0; i < out.length; i++) {
        if (out[i].$2.path == home) {
          out[i] = ('⌂', out[i].$2);
          out.removeRange(0, i);
          break;
        }
      }
    }
    return out;
  }
}

class _CrumbSegment extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  const _CrumbSegment({
    required this.label,
    required this.onTap,
    required this.isLast,
  });

  @override
  State<_CrumbSegment> createState() => _CrumbSegmentState();
}

class _CrumbSegmentState extends State<_CrumbSegment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isLast
        ? ConsoleSkin.fg
        : (_hover ? ConsoleSkin.fg : ConsoleSkin.fgDim);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: AtomLabel(
            widget.label,
            fontSize: ConsoleSkin.sizeTiny,
            color: color,
            mono: true,
          ),
        ),
      ),
    );
  }
}

// ─── Listing ───────────────────────────────────────────────────────────

class _Entry {
  final String name;
  final String path;
  final bool isFolder;
  const _Entry({required this.name, required this.path, required this.isFolder});
}

/// Reads [dir] synchronously, sorts folders first then audio files
/// alphabetically (case-insensitive), and skips hidden dotfiles. Returns
/// an empty list on permission errors / non-existent dirs — caller shows
/// the empty state.
List<_Entry> _readEntries(Directory dir) {
  try {
    final all = dir.listSync(followLinks: false);
    final folders = <_Entry>[];
    final files = <_Entry>[];
    for (final e in all) {
      final name = e.path.split(Platform.pathSeparator).last;
      if (name.startsWith('.')) continue;
      if (e is Directory) {
        folders.add(_Entry(name: name, path: e.path, isFolder: true));
      } else if (e is File && _isSupported(e.path)) {
        files.add(_Entry(name: name, path: e.path, isFolder: false));
      }
    }
    int byName(_Entry a, _Entry b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    folders.sort(byName);
    files.sort(byName);
    return [...folders, ...files];
  } catch (_) {
    return const [];
  }
}

class _Listing extends StatelessWidget {
  final Directory dir;
  final ValueChanged<Directory> onNavigate;
  const _Listing({required this.dir, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final entries = _readEntries(dir);
    if (entries.isEmpty) return const _Empty();
    final player = StudioScope.of(context);
    return StreamBuilder<String>(
      stream: player.stream.streamPath,
      initialData: player.state.streamPath,
      builder: (ctx, snap) {
        final current = _normalizeUri(snap.data ?? '');
        return ListView.builder(
          itemCount: entries.length,
          itemBuilder: (ctx, i) {
            final e = entries[i];
            return _Row(
              entry: e,
              isCurrent: !e.isFolder && current == e.path,
              onTap: () {
                if (e.isFolder) {
                  onNavigate(Directory(e.path));
                } else {
                  player.open(Media(e.path));
                }
              },
            );
          },
        );
      },
    );
  }

  static String _normalizeUri(String s) {
    if (s.startsWith('file://')) return Uri.decodeFull(s.substring(7));
    return s;
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: AtomLabel(
        'empty folder',
        fontSize: ConsoleSkin.sizeSmall,
        color: ConsoleSkin.fgFaint,
        mono: true,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Row extends StatefulWidget {
  final _Entry entry;
  final bool isCurrent;
  final VoidCallback onTap;
  const _Row({
    required this.entry,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => widget.onTap(),
        child: SizedBox(
          height: ConsoleSkin.row,
          child: CustomPaint(
            painter: _RowPainter(
              entry: widget.entry,
              isCurrent: widget.isCurrent,
              hover: _hover,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _RowPainter extends CustomPainter {
  final _Entry entry;
  final bool isCurrent;
  final bool hover;

  _RowPainter({
    required this.entry,
    required this.isCurrent,
    required this.hover,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = isCurrent || hover ? ConsoleSkin.bgRaised : ConsoleSkin.bg;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    if (isCurrent) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 2, size.height),
        Paint()..color = ConsoleSkin.accent,
      );
    }

    hairline(
      canvas,
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
    );

    final cy = size.height / 2;

    // Glyph column: small folder mark or file dot. Vector-drawn so it
    // stays consistent with the rest of the console aesthetic — no
    // unicode emoji that some fonts render colorfully and others don't.
    _drawTypeGlyph(canvas, Offset(12, cy));

    // Label
    final labelLeft = 26.0;
    final labelRight = (isCurrent ? size.width - 24.0 : size.width - 8.0)
        .clamp(labelLeft, double.infinity);
    final color = entry.isFolder
        ? ConsoleSkin.fg
        : (isCurrent ? ConsoleSkin.fg : ConsoleSkin.fgDim);
    final labelSize = Glyph.measure(
      entry.name,
      size: ConsoleSkin.sizeSmall,
      color: color,
      maxWidth: labelRight - labelLeft,
    );
    Glyph.draw(
      canvas,
      entry.name,
      offset: Offset(labelLeft, cy - labelSize.height / 2),
      size: ConsoleSkin.sizeSmall,
      color: color,
      maxWidth: labelRight - labelLeft,
    );

    // Currently-playing indicator on the right margin.
    if (isCurrent) {
      final cx = size.width - 14.0;
      const r = 4.0;
      final p = Path()
        ..moveTo(cx - r * 0.7, cy - r)
        ..lineTo(cx + r,        cy)
        ..lineTo(cx - r * 0.7, cy + r)
        ..close();
      canvas.drawPath(p, Paint()..color = ConsoleSkin.accent..isAntiAlias = true);
    }
  }

  void _drawTypeGlyph(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = entry.isFolder ? ConsoleSkin.fgDim : ConsoleSkin.fgFaint
      ..isAntiAlias = true;
    if (entry.isFolder) {
      // Right-pointing chevron — the reader's cue that clicking
      // descends into this entry.
      final p = Path()
        ..moveTo(center.dx - 2, center.dy - 4)
        ..lineTo(center.dx + 3, center.dy)
        ..lineTo(center.dx - 2, center.dy + 4);
      canvas.drawPath(
        p,
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeJoin = StrokeJoin.round,
      );
    } else {
      // Tiny filled dot — files are leaves, no interaction beyond
      // play, so the glyph stays minimal.
      canvas.drawCircle(center, 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_RowPainter old) =>
      old.entry.path != entry.path ||
      old.isCurrent != isCurrent ||
      old.hover != hover;
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(
        height: ConsoleSkin.hairlinePx,
        color: ConsoleSkin.hairline,
      );
}

// ─── Backward-compat helpers ──────────────────────────────────────────
//
// Kept here because [studio_app.dart] (drag-drop) and the topbar OPEN
// button import them. They build a multi-item queue when more than
// one file is dropped / selected at once. Single-file click in the
// browser above always uses [Player.open] for single-track replace.

const Set<String> _supportedExtensions = {
  // ── Containers ──────────────────────────────────────────────────
  // MP4 family (AAC / ALAC / Dolby / DTS / Opus / etc.)
  'mp4', 'm4v', 'm4a', 'm4b', 'm4p', 'm4r',
  'mov',
  // Matroska / WebM
  'mka', 'mkv', 'webm',
  // Ogg
  'ogg', 'oga', 'opus', 'spx',
  // MPEG-TS
  'ts', 'm2ts', 'mts',
  // AVI / Flash / 3GP
  'avi', 'flv', 'f4v', '3gp', '3g2',
  // ASF / WMA / WMV (audio track)
  'asf', 'wma', 'wmv',
  // RealMedia
  'rm', 'ra', 'ram',

  // ── Raw audio ───────────────────────────────────────────────────
  // MPEG audio
  'mp3', 'mp2', 'mp1', 'mpa',
  // AAC ADTS
  'aac', 'adts',
  // Dolby
  'ac3', 'eac3', 'ec3',
  // DTS
  'dts', 'dtshd', 'dtsma',
  // TrueHD / MLP
  'thd', 'truehd', 'mlp',
  // Lossless
  'flac', 'ape', 'tta', 'wv', 'shn',
  // DSD / SACD
  'dsf', 'dff',
  // Musepack
  'mpc',
  // AIFF
  'aiff', 'aif', 'aifc',
  // WAV / Wave64
  'wav', 'w64',
  // Sun / NeXT
  'au', 'snd',
  // Apple Core Audio
  'caf',
  // Creative
  'voc',
  // Mobile
  'amr', 'gsm',
  // ATRAC3 / 3+ / 9
  'aa3', 'oma', 'at3', 'at9',

  // ── Playlists (mpv expands these into the queue) ────────────────
  'm3u', 'm3u8', 'pls',
};

bool _isSupported(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return false;
  return _supportedExtensions.contains(path.substring(dot + 1).toLowerCase());
}

Future<void> pickAndAppendFiles(Player player) async {
  final r = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.any,
  );
  if (r == null) return;
  final paths = r.files
      .where((f) => f.path != null)
      .map((f) => f.path!)
      .toList();
  if (paths.isEmpty) return;
  await appendOrOpenAll(player, paths);
}

Future<void> appendOrOpenAll(Player player, List<String> paths) async {
  final filtered = paths.where(_isSupported).toList();
  if (filtered.isEmpty) return;
  final empty = player.state.playlist.items.isEmpty;
  if (empty) {
    await player.openAll(filtered.map((p) => Media(p)).toList());
  } else {
    for (final p in filtered) {
      await player.add(Media(p));
    }
  }
}
