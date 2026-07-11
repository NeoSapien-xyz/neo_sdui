import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import 'neo_sdui_theme.dart';

/// How a block reports a tap; the app resolves the action.
typedef ActionDispatch = void Function(BuildContext context, NeoAction action);

/// Runs child blocks through the renderer's resilient pipeline (for `tabs`).
typedef BlockListBuilder = List<Widget> Function(List<BlockNode> nodes);

/// Carries [theme] + [dispatch] + [buildBlocks] down the tree so blocks read
/// them ambiently. Theme compared by identity — the app swaps it to re-skin.
class NeoSduiScope extends InheritedWidget {
  const NeoSduiScope({
    required this.theme,
    required this.dispatch,
    required this.buildBlocks,
    required super.child,
    super.key,
  });

  final NeoSduiTheme theme;
  final ActionDispatch dispatch;
  final BlockListBuilder buildBlocks;

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
