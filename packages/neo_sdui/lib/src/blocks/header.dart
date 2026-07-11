import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// header: title + optional subtitle. `tone: accent|critical` tints the title
/// (default keeps the theme's baked title color).
Widget buildHeader(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final subtitle = node.stringOr('subtitle');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(node.stringOr('title', '')!,
          style: theme.titleTone(node.stringOr('tone'))),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: theme.subtitle),
      ],
    ],
  );
}
