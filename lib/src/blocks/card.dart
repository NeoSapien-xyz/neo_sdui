import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// card: optional thumbnail + title + optional subtitle + optional action.
/// One block for how_to's list item, the MCP client-picker, and footer nav.
Widget buildCard(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final thumb = node.stringOr('thumb');
  final subtitle = node.stringOr('subtitle');
  final action = node.stringOr('action');

  final row = Row(
    children: [
      if (thumb != null) ...[
        ClipRRect(
          borderRadius: theme.cardRadius,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Image.network(
              thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(color: theme.cardColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.stringOr('title', '')!, style: theme.cardTitle),
            if (subtitle != null) Text(subtitle, style: theme.cardSubtitle),
          ],
        ),
      ),
      if (action != null) Text('›', style: theme.cardTitle),
    ],
  );

  final card = DecoratedBox(
    decoration: BoxDecoration(color: theme.cardColor, borderRadius: theme.cardRadius),
    child: Padding(padding: const EdgeInsets.all(12), child: row),
  );

  if (action == null) return card;
  return GestureDetector(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: card,
  );
}
