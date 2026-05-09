import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../atoms/atom_dropdown.dart';
import '../../atoms/atom_knob.dart';
import '../../atoms/atom_label.dart';
import '../../atoms/atom_toggle.dart';
import '../../shell/studio_scope.dart';
import '../../skin/console_skin.dart';
import 'pro_plugin_window.dart';

/// Fallback editor for filters that don't carry a hand-crafted
/// [ProPluginWindow] of their own — the "simple value" filters whose
/// UI boils down to a small grid of knobs / toggles / dropdowns.
///
/// One [GenericFilterWindow] is built per filter via the per-filter
/// builders in [genericFilterBuilders]; the shared widget renders
/// the resulting [GenericFilterRow] list inside the same chrome a
/// custom pro window uses (header, close X, controls strip), so
/// every filter in the rack opens to the same console look.
class GenericFilterWindow extends StatelessWidget {
  final String filterName;
  final List<GenericFilterRow> Function(Player player) buildRows;
  final VoidCallback onClose;
  final String? description;

  const GenericFilterWindow({
    super.key,
    required this.filterName,
    required this.buildRows,
    required this.onClose,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final p = StudioScope.of(context);
    // Re-observe the bundle so each `updateAudioEffects` rebuild
    // produces a fresh row list with the latest values. Without
    // this, [buildRows] would run once at first paint and the knobs
    // would visually snap back to the captured-at-mount value the
    // moment the engine confirmed the change. Mirror of the pattern
    // every hand-crafted pro window already uses.
    return StreamBuilder<AudioEffects>(
      stream: p.stream.audioEffects,
      initialData: p.state.audioEffects,
      builder: (ctx, _) {
        return ProPluginWindow(
          filterName: filterName,
          onClose: onClose,
          graph: _Banner(filterName: filterName, description: description),
          controls: _RowsStrip(rows: buildRows(p)),
        );
      },
    );
  }
}

/// Single editable row in a [GenericFilterWindow]. Concrete
/// subclasses ([GenericKnobRow], [GenericToggleRow],
/// [GenericEnumRow]) own their own rendering — the base only
/// declares the [build] hook. Done this way (rather than via
/// pattern-matching in the parent widget) because Dart can't
/// sussume a `ValueChanged<T>` into `ValueChanged<dynamic>`
/// (contravariant function types), which made the dropdown route
/// crash at runtime with a `_TypeError`.
abstract class GenericFilterRow {
  const GenericFilterRow();
  Widget build(BuildContext context);
}

/// One numeric knob — typed bounds and default come from the
/// auto-generated `*Min` / `*Max` / `*Default` constants on the
/// matching `*Settings` class so the engine asserts can't fire.
class GenericKnobRow extends GenericFilterRow {
  final String label;
  final double value;
  final double min;
  final double max;
  final double defaultValue;
  final ValueChanged<double> onChanged;
  final String Function(double)? format;

  const GenericKnobRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.defaultValue,
    required this.onChanged,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    return AtomKnob(
      value: value,
      min: min,
      max: max,
      defaultValue: defaultValue,
      onChanged: onChanged,
      label: label,
      format: format ?? (v) => v.toStringAsFixed(2),
      size: 70,
    );
  }
}

/// One on/off toggle.
class GenericToggleRow extends GenericFilterRow {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const GenericToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AtomToggle(value: value, onChanged: onChanged),
        const SizedBox(width: 6),
        AtomLabel(
          label,
          fontSize: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgDim,
          mono: true,
        ),
      ],
    );
  }
}

/// One enum dropdown. The type parameter [T] flows from the call
/// site (e.g. `GenericEnumRow<AdeclickM>(...)`), and rendering stays
/// inside this class so [T] is concrete when [AtomDropdown] is
/// instantiated — no `(T) → void` ↔ `(dynamic) → void` coercion
/// (which Dart rejects for function-type contravariance).
class GenericEnumRow<T> extends GenericFilterRow {
  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T> onChanged;
  final String Function(T) format;

  const GenericEnumRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AtomLabel(
          label,
          fontSize: ConsoleSkin.sizeTiny,
          color: ConsoleSkin.fgDim,
          mono: true,
        ),
        const SizedBox(height: 4),
        AtomDropdown<T>(
          value: value,
          options: options,
          onChanged: onChanged,
          format: format,
          width: 130,
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String filterName;
  final String? description;
  const _Banner({required this.filterName, this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ConsoleSkin.bgDeep,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AtomLabel(
              filterName,
              fontSize: 22,
              color: ConsoleSkin.accent,
              mono: true,
              letterSpacing: 2.0,
            ),
            const SizedBox(height: 12),
            AtomLabel(
              description ?? 'simple-value editor',
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgFaint,
              mono: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowsStrip extends StatelessWidget {
  final List<GenericFilterRow> rows;
  const _RowsStrip({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        color: ConsoleSkin.bg,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Center(
          child: AtomLabel(
            'no editable parameters',
            fontSize: ConsoleSkin.sizeTiny,
            color: ConsoleSkin.fgFaint,
            mono: true,
          ),
        ),
      );
    }
    return Container(
      color: ConsoleSkin.bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [for (final r in rows) Builder(builder: r.build)],
      ),
    );
  }
}

/// Per-filter builders. Each entry returns the row list for THAT
/// filter, reading the bundle through `StudioScope.of(context)` and
/// writing back via [Player.updateAudioEffects].
///
/// To register a new filter:
///   1. Add an entry here keyed by the lavfi filter name.
///   2. The fallback in `pro_registry.dart` picks it up automatically
///      (any filter not in `proWindowFilters` opens the generic
///      window backed by this map).
typedef GenericFilterBuilder = List<GenericFilterRow> Function(Player player);

/// See `generic_filter_specs.dart` for the populated map. Kept
/// separate so this file holds only the framework / atoms.
