import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_shape.dart';

/// Layout primitives: arrange child blocks, carry no pixels (KTD10). Spacing and
/// surfaces come from the theme, not the wire.

/// row: children side by side, equal flex, themed gaps.
Widget buildRow(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final gap = scope.theme.blockSpacing;
  final kids = scope.buildBlocks(node.nodeList('children'));
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < kids.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: kids[i]),
      ],
    ],
  );
}

/// column: children stacked vertically with themed gaps.
Widget buildColumn(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  return _stack(scope.buildBlocks(node.nodeList('children')), scope.theme.blockSpacing);
}

/// group: children stacked inside a themed surface.
Widget buildGroup(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  return DecoratedBox(
    decoration: shapeDecoration(
      node.stringOr('shape'),
      theme.radiusLg,
      fallback: 'rounded',
      color: theme.surface,
    ),
    child: Padding(
      padding: EdgeInsets.all(theme.spaceMd),
      child: _stack(scope.buildBlocks(node.nodeList('children')), theme.blockSpacing),
    ),
  );
}

/// spacer: vertical gap of `blockSpacing * size` (size defaults to 1).
Widget buildSpacer(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  return SizedBox(height: theme.blockSpacing * node.intOr('size', 1)!);
}

Widget _stack(List<Widget> kids, double gap) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kids.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          kids[i],
        ],
      ],
    );
