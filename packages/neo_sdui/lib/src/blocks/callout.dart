import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_icon.dart';
import '_shape.dart';

/// callout: optional leading `icon` + title + bullet list. Surface derived from
/// `tone` (default/accent/critical); corner from the optional `shape` role
/// (default rounded); text is the on-surface role.
Widget buildCallout(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final title = node.stringOr('title');
  final text = theme.body.copyWith(color: theme.onSurface);
  final icon = leadingIcon(theme, node.stringOr('icon'), node.stringOr('tone'));
  final rawBullets = node.fields['bullets'];
  final bullets = rawBullets is List
      ? rawBullets.whereType<String>().toList()
      : const <String>[];
  // Nothing usable to show (no title, no string bullets) -> skip rather than
  // throw on a non-list `bullets` or paint a stray empty tinted square.
  if (title == null && bullets.isEmpty) return const SizedBox.shrink();
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
            if (icon != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  SizedBox(width: theme.spaceSm),
                  Expanded(child: Text(title, style: text)),
                ],
              )
            else
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
