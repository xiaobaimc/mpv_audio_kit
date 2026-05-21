import 'package:flutter/material.dart';

/// One numeric column of a [FilterListEditor] row — a labelled slider
/// with its own range and value formatter.
class FilterListColumn {
  final String label;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) fmt;

  const FilterListColumn({
    required this.label,
    required this.min,
    required this.max,
    required this.fmt,
    this.divisions = 100,
  });
}

/// Editor for a variable-length list of fixed-shape numeric rows.
///
/// Backs the typed-extension filter editors (echo taps, EQ bands, …):
/// each row holds one value per [columns] entry, rows can be added up
/// to [maxRows], removed, and edited. [onChanged] fires with the full
/// row list on every commit.
class FilterListEditor extends StatelessWidget {
  final String label;
  final List<FilterListColumn> columns;
  final List<List<double>> rows;
  final List<double> newRow;
  final int maxRows;
  final ValueChanged<List<List<double>>> onChanged;

  const FilterListEditor({
    super.key,
    required this.label,
    required this.columns,
    required this.rows,
    required this.newRow,
    required this.onChanged,
    this.maxRows = 16,
  });

  List<List<double>> get _copy => [
        for (final r in rows) [...r],
      ];

  void _editCell(int row, int col, double value) {
    final next = _copy;
    next[row][col] = value;
    onChanged(next);
  }

  void _removeRow(int row) => onChanged(_copy..removeAt(row));

  void _addRow() => onChanged([..._copy, [...newRow]]);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Text(
                '${rows.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'No entries',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FilterListRow(
                  index: i,
                  columns: columns,
                  values: rows[i],
                  onChanged: (col, v) => _editCell(i, col, v),
                  onRemove: () => _removeRow(i),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: rows.length >= maxRows ? null : _addRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterListRow extends StatelessWidget {
  final int index;
  final List<FilterListColumn> columns;
  final List<double> values;
  final void Function(int col, double value) onChanged;
  final VoidCallback onRemove;

  const _FilterListRow({
    required this.index,
    required this.columns,
    required this.values,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          for (var c = 0; c < columns.length; c++)
            _MiniSlider(
              column: columns[c],
              value: values[c],
              onChanged: (v) => onChanged(c, v),
            ),
        ],
      ),
    );
  }
}

/// Compact labelled slider for one [FilterListColumn] cell. Visual
/// updates happen during drag; [onChanged] fires only on release.
class _MiniSlider extends StatefulWidget {
  final FilterListColumn column;
  final double value;
  final ValueChanged<double> onChanged;

  const _MiniSlider({
    required this.column,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_MiniSlider> createState() => _MiniSliderState();
}

class _MiniSliderState extends State<_MiniSlider> {
  double? _drag;

  @override
  void didUpdateWidget(_MiniSlider old) {
    super.didUpdateWidget(old);
    if (_drag != null && widget.value != old.value) _drag = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final col = widget.column;
    final display = (_drag ?? widget.value).clamp(col.min, col.max);
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            col.label,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Slider(
            value: display,
            min: col.min,
            max: col.max,
            divisions: col.divisions,
            onChanged: (v) => setState(() => _drag = v),
            onChangeEnd: (v) {
              setState(() => _drag = null);
              widget.onChanged(v);
            },
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 58,
          child: Text(
            col.fmt(display),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
