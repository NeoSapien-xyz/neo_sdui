import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import 'neo_sdui_theme.dart';

/// How a block reports a tap. The renderer supplies this; the app resolves the
/// action (open a view, run a route, launch a URL).
typedef ActionDispatch = void Function(BuildContext context, NeoAction action);

/// Carries the app-supplied [theme] and the action [dispatch] down the tree so
/// every block reads them ambiently — no threading through constructors.
///
/// Theme is compared by identity in [updateShouldNotify]: the app hands in a
/// stable instance and swaps it wholesale (the `neo_ui` re-skin is a new
/// instance), so identity is both correct and cheap here.
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
