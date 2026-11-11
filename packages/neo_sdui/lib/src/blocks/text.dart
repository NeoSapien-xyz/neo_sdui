import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';

/// text: body copy. `emphasis: low` renders muted; else primary. `tone:"accent"`
/// (or an inline `{text, tone:"accent"}` run) paints the theme's accent gradient.
/// `variant:"footnote"` drops to the caption (fine-print) scale, muted — the
/// figma "Note: …" disclaimer, a dimmed line, not a card. `body` may be a string
/// or a list of runs.
Widget buildText(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final style = node.stringOr('variant') == 'footnote'
      ? theme.resolvedFootnote
      : node.stringOr('emphasis') == 'low'
          ? theme.resolvedParagraph.copyWith(color: theme.textMuted)
          : theme.resolvedParagraph;
  return neoText(theme, node.fields['body'], style, tone: node.stringOr('tone'));
}
