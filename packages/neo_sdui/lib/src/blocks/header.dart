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
/// drops to item scale (a sub-heading) via [HeadingScale]. `align:"center"`
/// centers the heading across the card (the troubleshooting "Still having
/// issues?" footer) — a layout role, never a look value.
Widget buildHeader(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final tone = node.stringOr('tone');
  // A string subtitle stays a plain `Text` (golden-stable, keeps its textAlign);
  // a run list routes through `neoText` so a `strong` run can read white against
  // the muted rest (the "Add those tasks to my Notion." use-case clause).
  final subtitleValue = node.fields['subtitle'];
  final hasSubtitle = subtitleValue is String || subtitleValue is List;
  final centered = node.stringOr('align') == 'center';
  // Section title (top-level) vs item title (inside a group card).
  final compact = HeadingScale.of(context);
  // A compact (in-card) heading still reads as a heading — primary (white), not
  // the muted body color; a `tone` overrides. A section title keeps theme.title.
  // The two scales are the theme's two roles (title vs body): the item title is
  // *body at heading weight*, never a size baked here — a block that pins a
  // fontSize/letterSpacing puts that value out of the theme's reach forever.
  final base = compact
      ? theme.body
          .copyWith(fontWeight: FontWeight.w500, color: theme.textPrimary)
      : theme.title;
  final subtitleStyle = compact
      ? theme.caption.copyWith(fontWeight: FontWeight.w500)
      : theme.subtitle;
  final accent = theme.accentFor(tone);
  final titleStyle = accent == null ? base : base.copyWith(color: accent.color);
  // A compact accent title takes the gradient across the full row width (figma's
  // flex-1 element), so a short label ends brighter instead of at the full stop.
  Widget title =
      neoText(theme, node.fields['title'], titleStyle, tone: tone, stretch: compact);
  // A plain section title takes the heading emboss — but the *mirror* of the
  // "Step n:" label: dark (grey) at the top fading to white at the foot, not the
  // label's white->grey. Same `titleGradient` role, same stops, reversed
  // orientation (begin<->end): the look value stays in the theme; only the
  // heading-vs-label direction is decided here. Applying it un-reversed fades the
  // title's foot to grey, which reads as an inverted gradient. Accent titles keep
  // their accent gradient; in-card sub-headings stay flat.
  final titleGradient = theme.titleGradient;
  if (tone == null && !compact && titleGradient is LinearGradient) {
    final emboss = LinearGradient(
      colors: titleGradient.colors,
      stops: titleGradient.stops,
      begin: titleGradient.end,
      end: titleGradient.begin,
      tileMode: titleGradient.tileMode,
      transform: titleGradient.transform,
    );
    title = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: emboss.createShader,
      child: title,
    );
  }
  final icon = leadingIcon(theme, node.stringOr('icon'), tone,
      size: base.fontSize ?? 20);
  final column = Column(
    crossAxisAlignment:
        centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
    children: [
      if (icon != null)
        Row(
          mainAxisSize: centered ? MainAxisSize.min : MainAxisSize.max,
          // An item heading (in a group) centers its glyph with the single-line
          // title — the "Export data" use-case row; a section heading keeps the
          // glyph top-aligned for a title that may wrap.
          crossAxisAlignment:
              compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            icon,
            SizedBox(width: theme.spaceSm),
            if (centered) title else Expanded(child: title),
          ],
        )
      else
        title,
      if (hasSubtitle) ...[
        const SizedBox(height: 4),
        // Figma's item subtitle is Work Sans Medium (w500), not the flat caption
        // weight — the "Summarise everything I said today." rows.
        if (subtitleValue is List)
          neoText(theme, subtitleValue, subtitleStyle)
        else
          Text(
            subtitleValue as String,
            style: subtitleStyle,
            textAlign: centered ? TextAlign.center : null,
          ),
      ],
    ],
  );
  // A centered heading stretches full width so it centers within the card;
  // otherwise it hugs its content at the leading edge (unchanged).
  return centered ? SizedBox(width: double.infinity, child: column) : column;
}
