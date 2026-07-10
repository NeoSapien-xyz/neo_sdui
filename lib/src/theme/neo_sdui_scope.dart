import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import 'neo_sdui_theme.dart';

/// How a block reports a tap; the app resolves the action.
typedef ActionDispatch = void Function(BuildContext context, NeoAction action);

/// Carries [theme] + [dispatch] down the tree so blocks read them ambiently.
/// Theme compared by identity — the app swaps the whole object to re-skin.
class NeoSduiScope extends InheritedWidget {
  const NeoSduiScope({
    required this.theme,
    required this.dispatch,
    required super.child,
    super.key,
  });

  final NeoSduiTheme theme;
  final ActionDispatch dispatch;

  static NeoSduiScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NeoSduiScope>();
    assert(
      scope != null,
      'No NeoSduiScope found. Blocks must be built inside a NeoSduiView.',
    );
    return scope!;
  }

  @override
  bool updateShouldNotify(NeoSduiScope old) =>
      !identical(theme, old.theme) || !identical(dispatch, old.dispatch);
}
