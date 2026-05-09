import 'package:flutter/widgets.dart';

import 'anequalizer_window.dart';
import 'equalizer_window.dart';

/// lavfi filter names that have a hand-crafted [ProPluginWindow]. The
/// rack reads this to render an `↗` button on the matching cards and
/// route clicks through [openProWindow].
const Set<String> proWindowFilters = {
  'equalizer',
  'anequalizer',
};

/// Open the pro window for [filterName] inside an Overlay. Returns
/// `null` if no pro window is registered for that name. The dispatch
/// is centralised here so each filter window is a leaf of its own
/// concern (model, painter, controls) and doesn't need to know how
/// the rack drives it.
OverlayEntry? openProWindow(BuildContext context, String filterName) {
  if (!proWindowFilters.contains(filterName)) return null;
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    entry.remove();
  }

  Widget content;
  switch (filterName) {
    case 'equalizer':
      content = EqualizerWindow(onClose: close);
      break;
    case 'anequalizer':
      content = AnequalizerWindow(onClose: close);
      break;
    default:
      return null;
  }

  entry = OverlayEntry(builder: (_) => content);
  overlay.insert(entry);
  return entry;
}
