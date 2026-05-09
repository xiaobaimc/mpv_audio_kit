import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../atoms/atom_close_x.dart';
import '../atoms/atom_label.dart';
import '../atoms/atom_text_input.dart';
import '../shell/studio_scope.dart';
import '../skin/console_skin.dart';
import 'filter_catalog.dart';

/// Full-screen modal that lists every shipped lavfi filter, with a
/// search bar and a sidebar of 8 categories. Clicking a filter flips
/// its `enabled` flag and closes the picker. Already-active filters
/// are dim and non-clickable. ESC / backdrop / × close.
class FilterPicker extends StatefulWidget {
  final VoidCallback onClose;
  const FilterPicker({super.key, required this.onClose});

  @override
  State<FilterPicker> createState() => _FilterPickerState();
}

class _FilterPickerState extends State<FilterPicker> {
  final _searchController = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  // null = "all categories" (used when search is non-empty too).
  FxCategory? _selected = FxCategory.values.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _matches(FxMeta f) {
    if (_query.isEmpty) {
      return _selected == null || f.category == _selected;
    }
    final q = _query.toLowerCase();
    return f.name.toLowerCase().contains(q) ||
        f.description.toLowerCase().contains(q);
  }

  void _pick(FxMeta f, AudioEffects bundle) {
    if (f.isOn(bundle)) return;
    final p = StudioScope.of(context);
    p.updateAudioEffects((b) => f.toggle(b, true));
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);

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
            _Header(onClose: widget.onClose),
            const _Hairline(),
            _SearchBar(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
            ),
            const _Hairline(),
            Expanded(
              child: StreamBuilder<AudioEffects>(
                stream: p.stream.audioEffects,
                initialData: p.state.audioEffects,
                builder: (ctx, snap) {
                  final bundle = snap.data ?? const AudioEffects();
                  final filtered = filterCatalog.where(_matches).toList();
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 180,
                        child: _Sidebar(
                          selected: _selected,
                          searchActive: _query.isNotEmpty,
                          onChange: (c) => setState(() => _selected = c),
                          counts: _categoryCounts(),
                        ),
                      ),
                      const _VHairline(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) => _FilterRow(
                            meta: filtered[i],
                            bundle: bundle,
                            onTap: () => _pick(filtered[i], bundle),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (e) {
        if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
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
    );
  }

  Map<FxCategory, int> _categoryCounts() {
    final m = <FxCategory, int>{
      for (final c in FxCategory.values) c: 0,
    };
    for (final f in filterCatalog) {
      m[f.category] = (m[f.category] ?? 0) + 1;
    }
    return m;
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel(
                'ADD EFFECT',
                fontSize: ConsoleSkin.sizeBody,
                color: ConsoleSkin.accent,
                mono: true,
                letterSpacing: 2,
                weight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Same `×` glyph the FX chips and pro-plugin windows use,
            // so the dismiss affordance reads consistently across the app.
            AtomCloseX(onTap: onClose),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel(
                'search',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgDim,
                mono: true,
              ),
            ),
            Expanded(
              child: AtomTextInput(
                controller: controller,
                onChanged: onChanged,
                width: double.infinity,
                height: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final FxCategory? selected;
  final bool searchActive;
  final ValueChanged<FxCategory?> onChange;
  final Map<FxCategory, int> counts;
  const _Sidebar({
    required this.selected,
    required this.searchActive,
    required this.onChange,
    required this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgRaised,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final c in FxCategory.values)
            _SidebarItem(
              label: c.title,
              count: counts[c] ?? 0,
              active: !searchActive && c == selected,
              onTap: () => onChange(c),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.label,
    required this.count,
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
          // Same 28-tall fixed row + centerLeft alignment the
          // preferences sidebar uses (`_SidebarItem` in
          // preferences_overlay.dart). Keeping the two sidebars
          // visually identical is load-bearing — they live next to
          // each other in the studio chrome and any divergence reads
          // as a bug.
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          child: Row(
            children: [
              Expanded(
                child: AtomLabel(
                  widget.label,
                  fontSize: ConsoleSkin.sizeSmall,
                  color: widget.active ? ConsoleSkin.fg : ConsoleSkin.fgDim,
                  mono: true,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              AtomLabel(
                '${widget.count}',
                fontSize: ConsoleSkin.sizeTiny,
                color: ConsoleSkin.fgFaint,
                mono: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  final FxMeta meta;
  final AudioEffects bundle;
  final VoidCallback onTap;
  const _FilterRow({
    required this.meta,
    required this.bundle,
    required this.onTap,
  });

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.meta.isOn(widget.bundle);
    return MouseRegion(
      cursor: on ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: on ? null : (_) => widget.onTap(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hover && !on ? ConsoleSkin.bgRaised : ConsoleSkin.bg,
            border: const Border(
              bottom: BorderSide(
                color: ConsoleSkin.hairline,
                width: ConsoleSkin.hairlinePx,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AtomLabel(
                      widget.meta.name,
                      fontSize: ConsoleSkin.sizeSmall,
                      color: on ? ConsoleSkin.fgFaint : ConsoleSkin.fg,
                      mono: true,
                      weight: FontWeight.w500,
                    ),
                    if (widget.meta.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AtomLabel(
                          widget.meta.description,
                          fontSize: ConsoleSkin.sizeTiny,
                          color: ConsoleSkin.fgFaint,
                          wrap: true,
                        ),
                      ),
                  ],
                ),
              ),
              if (on)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: AtomLabel(
                    'active',
                    fontSize: ConsoleSkin.sizeTiny,
                    color: ConsoleSkin.accent,
                    mono: true,
                  ),
                ),
            ],
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
