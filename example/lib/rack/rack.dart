import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_label.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import 'filter_catalog.dart';
import 'filter_picker.dart';
import 'fx_row.dart';

/// The af-chain rack: a horizontal [Wrap] of compact chips, one per
/// filter where `enabled = true` in the live `AudioEffects` bundle.
/// Each chip exposes the filter name plus a remove ×; clicking the
/// body opens the filter's dedicated page (the pro window) when the
/// filter has one. Editing always happens on the dedicated page —
/// there is no inline editor in the rack itself.
///
/// Chips fill the row left-to-right and wrap to the next line when
/// they overflow the rack's width, so the rack grows in HEIGHT as more
/// filters are added. Vertical scrolling kicks in only when even
/// wrapping cannot fit them in the rack's allocated height (resizable
/// via the bottom-panel handle).
class Rack extends StatefulWidget {
  const Rack({super.key});

  @override
  State<Rack> createState() => _RackState();
}

/// Lookup table from filter name to its catalogue entry — built once
/// at first access since [filterCatalog] is `final` and immutable.
final Map<String, FxMeta> _byName = {
  for (final f in filterCatalog) f.name: f,
};

class _RackState extends State<Rack> {
  OverlayEntry? _pickerEntry;
  /// Filter names the user has bypassed via the chip's toggle but kept
  /// in the rack. The bundle's `enabled` flag is the live bypass — when
  /// it's false the rack would normally hide the chip; this set keeps
  /// it visible so the user can flick the toggle back on.
  final Set<String> _bypassed = <String>{};

  void _openPicker() {
    if (_pickerEntry != null) return;
    final overlay = Overlay.of(context);
    _pickerEntry = OverlayEntry(
      builder: (ctx) => FilterPicker(onClose: _closePicker),
    );
    overlay.insert(_pickerEntry!);
  }

  void _closePicker() {
    _pickerEntry?.remove();
    _pickerEntry = null;
  }

  @override
  void dispose() {
    _pickerEntry?.remove();
    _pickerEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    return Container(
      color: ConsoleSkin.bg,
      child: StreamBuilder<AudioEffects>(
        stream: p.stream.audioEffects,
        initialData: p.state.audioEffects,
        builder: (ctx, snap) {
          final bundle = snap.data ?? const AudioEffects();
          // If a filter became enabled externally (re-picked from the
          // picker, set programmatically), drop it from the bypassed
          // set so the chip's state stays consistent with the bundle.
          _bypassed.removeWhere((name) {
            final meta = _byName[name];
            return meta != null && meta.isOn(bundle);
          });
          final inRack = filterCatalog
              .where((f) => f.isOn(bundle) || _bypassed.contains(f.name))
              .toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(count: inRack.length, onAdd: _openPicker),
              const _Hairline(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Wrap(
                    children: [
                      for (final meta in inRack)
                        FxChip(
                          key: ValueKey(meta.name),
                          filterName: meta.name,
                          active: meta.isOn(bundle),
                          onToggle: (on) {
                            p.updateAudioEffects((b) => meta.toggle(b, on));
                            setState(() {
                              if (on) {
                                _bypassed.remove(meta.name);
                              } else {
                                _bypassed.add(meta.name);
                              }
                            });
                          },
                          onRemove: () {
                            p.updateAudioEffects(
                                (b) => meta.toggle(b, false));
                            setState(() => _bypassed.remove(meta.name));
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  const _Header({required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const AtomLabel(
              'FX CHAIN',
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.accent,
              mono: true,
              letterSpacing: 1.5,
              weight: FontWeight.w500,
            ),
            const SizedBox(width: 8),
            AtomLabel(
              count == 0 ? '' : '$count',
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgDim,
              mono: true,
            ),
            const Spacer(),
            _AddButton(onTap: onAdd),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  State<_AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<_AddButton> {
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
          width: 22,
          height: 22,
          child: CustomPaint(painter: _PlusPainter(hover: _hover)),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  final bool hover;
  _PlusPainter({required this.hover});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 5.0;
    final paint = Paint()
      ..color = hover ? ConsoleSkin.accent : ConsoleSkin.fgDim
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(Offset(cx - r, cy), Offset(cx + r, cy), paint);
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.hover != hover;
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) => Container(
        height: ConsoleSkin.hairlinePx,
        color: ConsoleSkin.hairline,
      );
}
