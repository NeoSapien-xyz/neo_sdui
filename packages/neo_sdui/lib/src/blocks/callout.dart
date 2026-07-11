import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_shape.dart';

/// callout: optional title + bullet list. Surface derived from `tone`
/// (default/accent/critical); corner from the optional `shape` role (default
/// rounded); text is the on-surface role.
Widget buildCallout(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final title = node.stringOr('title');
  final text = theme.body.copyWith(color: theme.onSurface);
  final bullets =
      (node.fields['bullets'] as List?)?.whereType<String>().toList() ??
          const <String>[];
  return DecoratedBox(
    decoration: shapeDecoration(
      node.stringOr('shape'),
      theme.radiusMd,
      fallback: 'rounded',
      color: theme.toneSurface(node.stringOr('tone')),
    ),
    child: Padding(
      padding: EdgeInsets.all(theme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: text),
            SizedBox(height: theme.spaceSm),
          ],
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: text),
                  Expanded(child: Text(b, style: text)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
