import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';

/// header: title + optional subtitle. `tone: accent|critical` tints the title —
/// `accent` paints the theme's accent gradient when one is set; default keeps
/// the theme's baked title color. `title` may be a string or a list of runs.
Widget buildHeader(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final tone = node.stringOr('tone');
  final subtitle = node.stringOr('subtitle');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      neoText(theme, node.fields['title'], theme.titleTone(tone),
          accentAll: tone == 'accent'),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: theme.subtitle),
      ],
    ],
  );
}
