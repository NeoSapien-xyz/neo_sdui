import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';

/// steps: numbered captions. Each item builds in its own try/catch so one bad
/// item can't take out the rest (R8).
Widget buildSteps(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final items = node.mapList('items');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
          child: _item(theme, i + 1, items[i]),
        ),
    ],
  );
}

Widget _item(NeoSduiTheme theme, int n, Map<String, Object?> item) {
  final index = theme.body.copyWith(color: theme.accent, fontWeight: FontWeight.w600);
  Widget caption;
  try {
    caption = Text(item['caption']! as String, style: theme.body);
  } catch (_) {
    // Bad item -> keep the number, show a placeholder, keep numbering intact.
    caption = Text('—', key: const Key('step-error'), style: theme.body);
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$n', style: index),
      const SizedBox(width: 12),
      Expanded(child: caption),
    ],
  );
}
