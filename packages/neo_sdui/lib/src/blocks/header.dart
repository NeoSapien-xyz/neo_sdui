import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';
import '_icon.dart';

/// Heading scale for a subtree. A `group` (a card) pushes [compact]=true so its
/// child headers render as item-scale sub-headings — the "Here's what it does"
/// use-case rows are `header`s nested in a group, and read at ~body size, not
/// the 24px section title a top-level header gets. A document-outline rule
/// (nesting sets level), not per-guide code: the wire still names only `header`.
class HeadingScale extends InheritedWidget {
  const HeadingScale({required this.compact, required super.child, super.key});
  final bool compact;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeadingScale>()?.compact ??
      false;
  @override
  bool updateShouldNotify(HeadingScale old) => compact != old.compact;
}

/// header: optional leading `icon` + title + optional subtitle. `tone:
/// accent|critical` tints the title — `accent` paints the theme's accent
/// gradient when one is set; default keeps the theme's baked title color.
/// `title` may be a string or a list of runs. Nested in a `group`, the title
/// drops to item scale (a sub-heading) via [HeadingScale].
Widget buildHeader(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final tone = node.stringOr('tone');
  final subtitle = node.stringOr('subtitle');
  // Section title (top-level) vs item title (inside a group card).
  final compact = HeadingScale.of(context);
  final base = compact ? theme.body.copyWith(fontWeight: FontWeight.w500) : theme.title;
  final accent = theme.accentFor(tone);
  final titleStyle = accent == null ? base : base.copyWith(color: accent.color);
  final title = neoText(theme, node.fields['title'], titleStyle, tone: tone);
  final icon = leadingIcon(theme, node.stringOr('icon'), tone,
      size: base.fontSize ?? 20);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null)
        Row(
          // An item heading (in a group) centers its glyph with the single-line
          // title — the "Export data" use-case row; a section heading keeps the
          // glyph top-aligned for a title that may wrap.
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
        Text(subtitle, style: compact ? theme.caption : theme.subtitle),
      ],
    ],
  );
}
