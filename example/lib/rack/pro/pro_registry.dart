import 'package:flutter/widgets.dart';

import 'acompressor_window.dart';
import 'acrusher_window.dart';
import 'adynamicequalizer_window.dart';
import 'aecho_window.dart';
import 'agate_window.dart';
import 'alimiter_window.dart';
import 'anequalizer_window.dart';
import 'adelay_window.dart';
import 'aphaser_window.dart';
import 'apulsator_window.dart';
import 'chorus_window.dart';
import 'headphone_window.dart';
import 'compand_window.dart';
import 'deesser_window.dart';
import 'ebur128_window.dart';
import 'equalizer_window.dart';
import 'firequalizer_window.dart';
import 'flanger_window.dart';
import 'loudnorm_window.dart';
import 'mcompand_window.dart';
import 'stereotools_window.dart';
import 'superequalizer_window.dart';
import 'tremolo_window.dart';
import 'vibrato_window.dart';
import 'generic_filter_specs.dart';
import 'generic_filter_window.dart';

/// lavfi filter names that have a hand-crafted [ProPluginWindow]. The
/// rack reads this to render an `↗` button on the matching cards and
/// route clicks through [openProWindow].
const Set<String> proWindowFilters = {
  'acompressor',
  'acrusher',
  'adelay',
  'adynamicequalizer',
  'aecho',
  'agate',
  'alimiter',
  'equalizer',
  'anequalizer',
  'aphaser',
  'apulsator',
  'chorus',
  'compand',
  'deesser',
  'ebur128',
  'firequalizer',
  'flanger',
  'headphone',
  'loudnorm',
  'mcompand',
  'stereotools',
  'superequalizer',
  'tremolo',
  'vibrato',
};

/// True when [filterName] has either a hand-crafted pro window or a
/// generic-fallback editor registered. The rack reads this to decide
/// whether to render the chip's `↗` open-page glyph; only filters
/// whose UI is "purely the chip" (no parameters worth surfacing) skip
/// the glyph.
bool hasAnyEditor(String filterName) =>
    proWindowFilters.contains(filterName) ||
    genericFilterBuilders.containsKey(filterName);

/// Open the editor for [filterName] inside an Overlay. Returns `null`
/// only when the filter has neither a hand-crafted pro window nor a
/// generic-fallback row spec — those are the truly parameter-less
/// utility filters (`aderivative`, `aformat`, `earwax`, `pan`,
/// `aeval`, `channelmap`, `hdcd`, …) where the chip alone IS the UI.
OverlayEntry? openProWindow(BuildContext context, String filterName) {
  if (!hasAnyEditor(filterName)) return null;
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
    case 'acompressor':
      content = AcompressorWindow(onClose: close);
      break;
    case 'acrusher':
      content = AcrusherWindow(onClose: close);
      break;
    case 'adelay':
      content = AdelayWindow(onClose: close);
      break;
    case 'adynamicequalizer':
      content = AdynamicequalizerWindow(onClose: close);
      break;
    case 'aecho':
      content = AechoWindow(onClose: close);
      break;
    case 'agate':
      content = AgateWindow(onClose: close);
      break;
    case 'alimiter':
      content = AlimiterWindow(onClose: close);
      break;
    case 'equalizer':
      content = EqualizerWindow(onClose: close);
      break;
    case 'anequalizer':
      content = AnequalizerWindow(onClose: close);
      break;
    case 'aphaser':
      content = AphaserWindow(onClose: close);
      break;
    case 'apulsator':
      content = ApulsatorWindow(onClose: close);
      break;
    case 'chorus':
      content = ChorusWindow(onClose: close);
      break;
    case 'compand':
      content = CompandWindow(onClose: close);
      break;
    case 'deesser':
      content = DeesserWindow(onClose: close);
      break;
    case 'ebur128':
      content = Ebur128Window(onClose: close);
      break;
    case 'firequalizer':
      content = FirequalizerWindow(onClose: close);
      break;
    case 'flanger':
      content = FlangerWindow(onClose: close);
      break;
    case 'headphone':
      content = HeadphoneWindow(onClose: close);
      break;
    case 'loudnorm':
      content = LoudnormWindow(onClose: close);
      break;
    case 'mcompand':
      content = McompandWindow(onClose: close);
      break;
    case 'stereotools':
      content = StereotoolsWindow(onClose: close);
      break;
    case 'superequalizer':
      content = SuperequalizerWindow(onClose: close);
      break;
    case 'tremolo':
      content = TremoloWindow(onClose: close);
      break;
    case 'vibrato':
      content = VibratoWindow(onClose: close);
      break;
    default:
      // Fall through to the generic-fallback editor when a row spec
      // is registered for [filterName]; otherwise the filter has no
      // surface-able parameters and the chip alone is the UI.
      final builder = genericFilterBuilders[filterName];
      if (builder == null) return null;
      content = GenericFilterWindow(
        filterName: filterName,
        buildRows: builder,
        onClose: close,
      );
  }

  entry = OverlayEntry(builder: (_) => content);
  overlay.insert(entry);
  return entry;
}
