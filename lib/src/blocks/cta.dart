import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// cta: tappable pill. Fill/text derived from `emphasis` (high/normal/low).
Widget buildCta(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final action = node.stringOr('action', '')!;
  final emphasis = node.stringOr('emphasis');
  final label = theme.body.copyWith(
    color: theme.onFill(emphasis),
    fontWeight: FontWeight.w500,
  );
  return GestureDetector(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.fill(emphasis),
        borderRadius: theme.radiusMd,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: theme.spaceLg),
        child: Center(child: Text(node.stringOr('label', '')!, style: label)),
      ),
    ),
  );
}
