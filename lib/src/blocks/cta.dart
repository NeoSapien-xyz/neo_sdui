import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// cta: tappable pill carrying an inline action string.
Widget buildCta(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final action = node.stringOr('action', '')!;
  return GestureDetector(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: theme.ctaBackground,
        borderRadius: theme.ctaRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Center(child: Text(node.stringOr('label', '')!, style: theme.ctaLabel)),
      ),
    ),
  );
}
