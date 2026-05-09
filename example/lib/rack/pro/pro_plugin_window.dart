import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../atoms/atom_close_x.dart';
import '../../atoms/atom_label.dart';
import '../../skin/console_skin.dart';

/// Reusable shell for "pro plugin"-style filter editors. Layout:
///
/// ```
/// +- header --- name --------- [×] -+
/// +----------------------------------+
/// |                                  |
/// |        graph (caller-owned)      |
/// |                                  |
/// +----------------------------------+
/// |   controls (caller-owned)        |
/// +----------------------------------+
/// ```
///
/// Modal frame (backdrop, ESC, click-outside close) and clip-rounding
/// are factored out so each filter window only ships its graph + knobs.
class ProPluginWindow extends StatefulWidget {
  final String filterName;
  final VoidCallback onClose;
  final Widget graph;
  final Widget controls;
  final double maxWidth;
  final double maxHeight;

  const ProPluginWindow({
    super.key,
    required this.filterName,
    required this.onClose,
    required this.graph,
    required this.controls,
    this.maxWidth = 720,
    this.maxHeight = 540,
  });

  @override
  State<ProPluginWindow> createState() => _ProPluginWindowState();
}

class _ProPluginWindowState extends State<ProPluginWindow> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final window = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      ),
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
            _Header(
              filterName: widget.filterName,
              onClose: widget.onClose,
            ),
            const _Hairline(),
            Expanded(child: widget.graph),
            const _Hairline(),
            widget.controls,
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
}

class _Header extends StatelessWidget {
  final String filterName;
  final VoidCallback onClose;
  const _Header({required this.filterName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AtomLabel(
                filterName,
                fontSize: ConsoleSkin.sizeBody,
                color: ConsoleSkin.accent,
                mono: true,
                letterSpacing: 1.5,
                weight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            AtomCloseX(onTap: onClose),
          ],
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
