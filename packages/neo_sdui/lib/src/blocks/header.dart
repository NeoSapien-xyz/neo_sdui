import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';
import '_icon.dart';

/// header: optional leading `icon` + title + optional subtitle. `tone:
/// accent|critical` tints the title — `accent` paints the theme's accent
/// gradient when one is set; default keeps the theme's baked title color.
/// `title` may be a string or a list of runs.
Widget buildHeader(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final tone = node.stringOr('tone');
  final subtitle = node.stringOr('subtitle');
  final title =
      neoText(theme, node.fields['title'], theme.titleTone(tone), tone: tone);
  final icon = leadingIcon(theme, node.stringOr('icon'), tone,
      size: theme.title.fontSize ?? 20);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            SizedBox(width: theme.spaceSm),
            Expanded(child: title),
          ],
        )
      else
        title,
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle, style: theme.subtitle),
      ],
    ],
  );
}
