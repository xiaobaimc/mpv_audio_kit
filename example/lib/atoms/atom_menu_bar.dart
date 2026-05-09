import 'package:flutter/widgets.dart';

import '../skin/console_skin.dart';
import 'atom_label.dart';

/// One entry in a menu's pull-down list.
sealed class MenuEntry {
  const MenuEntry();
}

/// Clickable action. [shortcutHint] is right-aligned in muted text
/// (purely informational — no key handling at this layer).
class MenuAction extends MenuEntry {
  final String label;
  final String? shortcutHint;
  final bool enabled;
  final VoidCallback onTap;

  const MenuAction({
    required this.label,
    required this.onTap,
    this.shortcutHint,
    this.enabled = true,
  });
}

/// Visual hairline separating groups of [MenuAction]s.
class MenuDivider extends MenuEntry {
  const MenuDivider();
}

/// One pull-down: a [label] in the bar that opens [items] when clicked.
class MenuPullDown {
  final String label;
  final List<MenuEntry> items;
  const MenuPullDown({required this.label, required this.items});
}

/// Horizontal strip of [MenuPullDown]s. Each label owns its own
/// popover; cross-label coordination ("click another label closes
/// this one, opens that one") is handled by [TapRegion] groupIds —
/// each `(label, popover)` pair shares an Object identity, so a tap
/// on a sibling label registers as outside this label's group and
/// fires its `onTapOutside` close hook automatically.
class MenuBar extends StatefulWidget {
  final List<MenuPullDown> menus;

  const MenuBar({super.key, required this.menus});

  @override
  State<MenuBar> createState() => _MenuBarState();
}

class _MenuBarState extends State<MenuBar> {
  // One group per menu — stable identity across rebuilds.
  late List<Object> _groupIds;

  @override
  void initState() {
    super.initState();
    _groupIds = List.generate(widget.menus.length, (_) => Object());
  }

  @override
  void didUpdateWidget(covariant MenuBar old) {
    super.didUpdateWidget(old);
    if (old.menus.length != widget.menus.length) {
      _groupIds = List.generate(widget.menus.length, (_) => Object());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      // Stretch so each label fills the topbar height. The label's
      // render-box bottom then equals the topbar's bottom, which is
      // where we anchor the popover — no extra offset, no gap.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.menus.length; i++)
          _MenuLabel(
            key: ValueKey(_groupIds[i]),
            menu: widget.menus[i],
            groupId: _groupIds[i],
          ),
      ],
    );
  }
}

class _MenuLabel extends StatefulWidget {
  final MenuPullDown menu;
  final Object groupId;

  const _MenuLabel({
    super.key,
    required this.menu,
    required this.groupId,
  });

  @override
  State<_MenuLabel> createState() => _MenuLabelState();
}

class _MenuLabelState extends State<_MenuLabel> {
  final _controller = OverlayPortalController();
  final _labelKey = GlobalKey();
  bool _hover = false;

  void _show() {
    if (_controller.isShowing) return;
    _controller.show();
    if (mounted) setState(() {});
  }

  void _hide() {
    if (!_controller.isShowing) return;
    _controller.hide();
    if (mounted) setState(() {});
  }

  void _toggle() => _controller.isShowing ? _hide() : _show();

  Color get _labelColor {
    if (_controller.isShowing) return ConsoleSkin.accent;
    if (_hover) return ConsoleSkin.fg;
    return ConsoleSkin.fgDim;
  }

  @override
  void dispose() {
    if (_controller.isShowing) _controller.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (overlayContext) {
        final box =
            _labelKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return const SizedBox.shrink();
        final origin = box.localToGlobal(Offset.zero);
        final size = box.size;
        return Positioned(
          left: origin.dx,
          top: origin.dy + size.height,
          child: TapRegion(
            groupId: widget.groupId,
            onTapOutside: (_) => _hide(),
            child: _MenuPopover(
              items: widget.menu.items,
              onClosed: _hide,
            ),
          ),
        );
      },
      // Label and popover share the same groupId so a tap on the
      // label is "inside" the group — the popover's onTapOutside
      // does NOT fire. A tap on a sibling label (which has its own
      // group) IS outside this group and triggers the close hook,
      // while the sibling's GestureDetector simultaneously opens
      // its own popover. One click, both transitions.
      child: TapRegion(
        groupId: widget.groupId,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: Container(
              key: _labelKey,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              child: AtomLabel(
                widget.menu.label,
                fontSize: ConsoleSkin.sizeSmall,
                color: _labelColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuPopover extends StatelessWidget {
  final List<MenuEntry> items;
  final VoidCallback onClosed;

  const _MenuPopover({required this.items, required this.onClosed});

  static const double _minWidth = 200;
  static const double _rowHeight = 24;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: _minWidth),
      decoration: BoxDecoration(
        color: ConsoleSkin.bgRaised,
        border: Border.all(
          color: ConsoleSkin.hairline,
          width: ConsoleSkin.hairlinePx,
        ),
      ),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final entry in items)
              if (entry is MenuDivider)
                Container(
                  height: ConsoleSkin.hairlinePx,
                  color: ConsoleSkin.hairline,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                )
              else if (entry is MenuAction)
                _MenuActionRow(
                  action: entry,
                  rowHeight: _rowHeight,
                  onAfterTap: onClosed,
                ),
          ],
        ),
      ),
    );
  }
}

class _MenuActionRow extends StatefulWidget {
  final MenuAction action;
  final double rowHeight;
  final VoidCallback onAfterTap;

  const _MenuActionRow({
    required this.action,
    required this.rowHeight,
    required this.onAfterTap,
  });

  @override
  State<_MenuActionRow> createState() => _MenuActionRowState();
}

class _MenuActionRowState extends State<_MenuActionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.action;
    final disabled = !a.enabled;
    final hovered = _hover && !disabled;

    final fg = disabled
        ? ConsoleSkin.fgFaint
        : (hovered ? ConsoleSkin.bg : ConsoleSkin.fg);
    final bg = hovered ? ConsoleSkin.accent : const Color(0x00000000);
    final hintFg = disabled
        ? ConsoleSkin.fgFaint
        : (hovered ? ConsoleSkin.bg : ConsoleSkin.fgDim);

    return MouseRegion(
      cursor: disabled
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: disabled
            ? null
            : () {
                a.onTap();
                widget.onAfterTap();
              },
        child: Container(
          height: widget.rowHeight,
          // 7 horizontal so the action label sits at popover_left + 1
          // (popover border) + 7 = popover_left + 8 — matching the
          // menu-label text above (which has 8 of container padding,
          // no border).
          padding: const EdgeInsets.symmetric(horizontal: 7),
          color: bg,
          child: Row(
            children: [
              Expanded(
                child: AtomLabel(
                  a.label,
                  fontSize: ConsoleSkin.sizeBody,
                  color: fg,
                ),
              ),
              if (a.shortcutHint != null) ...[
                const SizedBox(width: 12),
                AtomLabel(
                  a.shortcutHint!,
                  fontSize: ConsoleSkin.sizeSmall,
                  color: hintFg,
                  mono: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
