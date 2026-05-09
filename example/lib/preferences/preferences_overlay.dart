import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../atoms/atom_button.dart';
import '../atoms/atom_label.dart';
import '../skin/console_skin.dart';
import 'prefs_bus.dart';
import 'preferences_sections.dart';

enum _Section { audio, decoder, gain, network, cache, fft, cover, advanced }

extension _SectionMeta on _Section {
  String get title => switch (this) {
        _Section.audio    => 'AUDIO OUTPUT',
        _Section.decoder  => 'DECODER',
        _Section.gain     => 'REPLAY-GAIN',
        _Section.network  => 'NETWORK',
        _Section.cache    => 'CACHE & DEMUXER',
        _Section.fft      => 'VISUALIZER',
        _Section.cover    => 'COVER ART',
        _Section.advanced => 'ADVANCED',
      };
}

/// Modal preferences screen. Live-apply with revert: every row writes
/// to mpv immediately AND records how to undo. The footer's Cancel
/// undoes every change since open / last Apply; Apply commits the
/// baseline; Save commits + closes.
class PreferencesOverlay extends StatefulWidget {
  final VoidCallback onClose;
  const PreferencesOverlay({super.key, required this.onClose});

  @override
  State<PreferencesOverlay> createState() => _PreferencesOverlayState();
}

class _PreferencesOverlayState extends State<PreferencesOverlay> {
  final _bus = PrefsBus();
  final _focus = FocusNode();
  _Section _section = _Section.audio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _bus.dispose();
    _focus.dispose();
    super.dispose();
  }

  Widget _content() => switch (_section) {
        _Section.audio    => const AudioOutputSection(),
        _Section.decoder  => const DecoderSection(),
        _Section.gain     => const ReplayGainSection(),
        _Section.network  => const NetworkSection(),
        _Section.cache    => const CacheSection(),
        _Section.fft      => const VisualizerSection(),
        _Section.cover    => const CoverArtSection(),
        _Section.advanced => const AdvancedSection(),
      };

  Future<void> _cancel() async {
    await _bus.revertAll();
    widget.onClose();
  }

  void _apply() => _bus.commit();

  void _save() {
    _bus.commit();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final window = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 540),
      child: Container(
        decoration: BoxDecoration(
          color: ConsoleSkin.bg,
          border: Border.all(
            color: ConsoleSkin.hairline,
            width: ConsoleSkin.hairlinePx,
          ),
          borderRadius: BorderRadius.circular(ConsoleSkin.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _Header(),
            const _Hairline(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 160,
                    child: _Sidebar(
                      section: _section,
                      onChange: (s) => setState(() => _section = s),
                    ),
                  ),
                  const _VHairline(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AtomLabel(
                            _section.title,
                            fontSize: ConsoleSkin.sizeH1,
                            color: ConsoleSkin.fg,
                            mono: true,
                            letterSpacing: 1.5,
                            weight: FontWeight.w500,
                          ),
                          const SizedBox(height: 12),
                          _content(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _Hairline(),
            _Footer(
              bus: _bus,
              onCancel: _cancel,
              onApply: _apply,
              onSave: _save,
            ),
          ],
        ),
      ),
    );

    return PrefsScope(
      bus: _bus,
      child: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (e) {
          if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
            _cancel();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _cancel,
                child: const ColoredBox(color: Color(0xB0000000)),
              ),
            ),
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: window,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 40,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AtomLabel(
            'PREFERENCES',
            fontSize: ConsoleSkin.sizeBody,
            color: ConsoleSkin.accent,
            mono: true,
            letterSpacing: 2,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final PrefsBus bus;
  final Future<void> Function() onCancel;
  final VoidCallback onApply;
  final VoidCallback onSave;

  const _Footer({
    required this.bus,
    required this.onCancel,
    required this.onApply,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: AnimatedBuilder(
        animation: bus,
        builder: (ctx, _) {
          final dirty = bus.isDirty;
          return Row(
            children: [
              if (dirty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: AtomLabel(
                    'unsaved changes',
                    fontSize: ConsoleSkin.sizeTiny,
                    color: ConsoleSkin.accent,
                    mono: true,
                  ),
                ),
              const Spacer(),
              AtomButton(
                label: 'CANCEL',
                onTap: () => onCancel(),
                width: 80,
                height: 20,
              ),
              AtomButton(
                label: 'APPLY',
                onTap: onApply,
                width: 80,
                height: 20,
                enabled: dirty,
              ),
              AtomButton(
                label: 'SAVE',
                onTap: onSave,
                width: 80,
                height: 20,
                toggled: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final _Section section;
  final ValueChanged<_Section> onChange;
  const _Sidebar({required this.section, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgRaised,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _Section.values
            .map((s) => _SidebarItem(
                  label: s.title,
                  active: s == section,
                  onTap: () => onChange(s),
                ))
            .toList(),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
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
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: widget.active
                ? ConsoleSkin.bg
                : (_hover ? ConsoleSkin.bgDeep : ConsoleSkin.bgRaised),
            border: widget.active
                ? const Border(
                    left: BorderSide(color: ConsoleSkin.accent, width: 2),
                  )
                : null,
          ),
          child: AtomLabel(
            widget.label,
            fontSize: ConsoleSkin.sizeSmall,
            color: widget.active ? ConsoleSkin.fg : ConsoleSkin.fgDim,
            mono: true,
            letterSpacing: 0.8,
          ),
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

class _VHairline extends StatelessWidget {
  const _VHairline();
  @override
  Widget build(BuildContext context) =>
      Container(width: ConsoleSkin.hairlinePx, color: ConsoleSkin.hairline);
}
