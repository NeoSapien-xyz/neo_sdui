import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_shape.dart';

/// cta: tappable pill. Fill/text derived from `emphasis` (high/normal/low);
/// corner from the optional `shape` role (default rounded).
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
      decoration: shapeDecoration(
        node.stringOr('shape'),
        theme.radiusMd,
        fallback: 'rounded',
        color: theme.fill(emphasis),
        // A featured cta (emphasis:high) fills with the branded ctaGradient when
        // the theme sets one; null keeps the flat accent fill, byte-identical.
        gradient: emphasis == 'high' ? theme.ctaGradient : null,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: theme.spaceLg),
        child: Center(child: Text(node.stringOr('label', '')!, style: label)),
      ),
    ),
  );
}
