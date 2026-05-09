import 'package:flutter/widgets.dart';

/// Tracks per-row revert closures so the modal's Cancel button can
/// undo every change the user made since opening (or since the last
/// Apply). Live-apply is preserved — every row writes through to mpv
/// immediately AND records how to undo that write.
///
/// Multiple changes to the same field stack: each capture records the
/// state BEFORE the new write, so replaying reverts in reverse order
/// always lands back on the originally-opened value.
class PrefsBus extends ChangeNotifier {
  final List<Future<void> Function()> _reverts = [];

  bool get isDirty => _reverts.isNotEmpty;

  /// Captures `before` and immediately applies `after`. Equality-skipped.
  void apply<T>({
    required T currentValue,
    required T newValue,
    required void Function(T) setter,
  }) {
    if (currentValue == newValue) return;
    _reverts.add(() async => setter(currentValue));
    setter(newValue);
    notifyListeners();
  }

  /// Replays reverts in reverse order. Called from Cancel.
  Future<void> revertAll() async {
    for (final r in _reverts.reversed) {
      try {
        await r();
      } catch (_) {/* ignore - best-effort revert */}
    }
    _reverts.clear();
    notifyListeners();
  }

  /// Drops the revert log. Called from Apply / Save — the user has
  /// committed; future Cancel won't reach past this point.
  void commit() {
    if (_reverts.isEmpty) return;
    _reverts.clear();
    notifyListeners();
  }
}

class PrefsScope extends InheritedNotifier<PrefsBus> {
  const PrefsScope({super.key, required PrefsBus bus, required super.child})
      : super(notifier: bus);

  static PrefsBus of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PrefsScope>();
    assert(scope != null, 'PrefsScope.of() called outside the prefs tree');
    return scope!.notifier!;
  }
}
