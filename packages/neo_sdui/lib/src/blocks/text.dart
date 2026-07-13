import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';

/// text: body copy. `emphasis: low` renders muted; else primary. `tone:"accent"`
/// (or an inline `{text, tone:"accent"}` run) paints the theme's accent gradient.
/// `body` may be a string or a list of runs.
Widget buildText(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  return neoText(
    theme,
    node.fields['body'],
    theme.bodyEmphasis(node.stringOr('emphasis')),
    accentAll: node.stringOr('tone') == 'accent',
  );
}
