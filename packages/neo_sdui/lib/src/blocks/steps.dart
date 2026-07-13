import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import 'code.dart';

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
  Widget body;
  try {
    final cap = item['caption'];
    if (cap is! String && cap is! List) {
      throw StateError('step caption must be a string or a run list');
    }
    final caption = neoText(theme, cap, theme.body);
    // Optional muted sub-line and optional copyable command under the caption;
    // both absent -> caption only (R4).
    final detail = item['detail'];
    final code = item['code'];
    final extras = <Widget>[
      if (detail is String) Text(detail, style: theme.caption),
      if (code is String) ...[
        SizedBox(height: theme.spaceSm),
        codeChip(code),
      ],
    ];
    body = extras.isEmpty
        ? caption
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, ...extras],
          );
  } catch (_) {
    // Bad item -> keep the number, show a placeholder, keep numbering intact.
    body = Text('—', key: const Key('step-error'), style: theme.body);
  }
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      neoText(theme, '$n', index, accentAll: true),
      const SizedBox(width: 12),
      Expanded(child: body),
    ],
  );
}
