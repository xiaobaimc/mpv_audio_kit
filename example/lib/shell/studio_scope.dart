import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Provides the [Player] to the descendant tree without dragging it
/// through every constructor. Read with [StudioScope.of].
class StudioScope extends InheritedWidget {
  final Player player;

  const StudioScope({
    super.key,
    required this.player,
    required super.child,
  });

  static Player of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StudioScope>();
    assert(scope != null, 'StudioScope.of() called outside the studio tree');
    return scope!.player;
  }

  @override
  bool updateShouldNotify(StudioScope old) => old.player != player;
}
