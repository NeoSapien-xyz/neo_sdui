import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// callout: optional title + bullet list. `severity` is a wire token; the theme
/// currently exposes one callout treatment, so all severities share it.
// ponytail: add per-severity theme slots if design splits info/warn/critical.
Widget buildCallout(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final title = node.stringOr('title');
  final bullets =
      (node.fields['bullets'] as List?)?.whereType<String>().toList() ??
          const <String>[];
  return DecoratedBox(
    decoration: BoxDecoration(
      color: theme.calloutBackground,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: theme.calloutText),
            const SizedBox(height: 8),
          ],
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: theme.calloutText),
                  Expanded(child: Text(b, style: theme.calloutText)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
