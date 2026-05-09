import 'package:flutter/widgets.dart';

import '../atoms/atom_label.dart';
import '../atoms/atom_number_input.dart';
import '../skin/console_skin.dart';

/// Compact parameter row used inside an [FxRow]'s inline editor (and
/// formerly inside [EffectCard]). Label on the left, number input on
/// the right. ~22 px tall, no border — designed to stack densely in
/// the FX rack.
class ParamRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final int decimals;

  const ParamRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.decimals = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        children: [
          Expanded(
            child: AtomLabel(
              label,
              fontSize: ConsoleSkin.sizeTiny,
              color: ConsoleSkin.fgDim,
              mono: true,
            ),
          ),
          AtomNumberInput(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            decimals: decimals,
            width: 70,
          ),
        ],
      ),
    );
  }
}
