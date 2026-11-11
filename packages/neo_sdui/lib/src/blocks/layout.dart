import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_grid.dart';
import '_shape.dart';
import 'card.dart';
import 'header.dart';

/// Layout primitives: arrange child blocks, carry no pixels (KTD10). Spacing and
/// surfaces come from the theme, not the wire.

/// row: children side by side, equal flex, themed gaps.
Widget buildRow(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final gap = scope.theme.blockSpacing;
  final kids = scope.buildBlocks(node.nodeList('children'));
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < kids.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: kids[i]),
      ],
    ],
  );
}

/// column: children stacked vertically with themed gaps. `variant:"tight"` uses
/// the item gap (spaceMd) instead of the block gap — the figma picker-card group
/// (gap-12) vs the default section rhythm (blockSpacing).
Widget buildColumn(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final gap = node.stringOr('variant') == 'tight'
      ? scope.theme.spaceMd
      : scope.theme.blockSpacing;
  final kids = scope.buildBlocks(node.nodeList('children'));
  // Stretch children to full width so a stacked `card` (a Row with an Expanded)
  // gets bounded width, exactly as it does as a top-level view block.
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < kids.length; i++) ...[
        if (i > 0) SizedBox(height: gap),
        kids[i],
      ],
    ],
  );
}

/// group: children stacked inside a themed surface. A *featured* group
/// (`emphasis:"high"`) also paints the theme's grid texture behind its children.
///
/// Three render modes layer on top: (1) a *menu card* — `variant:"list"`, or a
/// group whose children are all `card`s — draws one shared surface and tells each
/// child via [CardListed] to render as a compact flat row; (2) otherwise every
/// child header is pushed to item-scale via [HeadingScale] (use-case sub-titles,
/// not section titles); (3) `variant:"tight"` pulls the inter-child gap in to
/// `spaceSm`. Each is layout/look the wire only names by role.
Widget buildGroup(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final shape = node.stringOr('shape');
  // A menu card: one shared surface holding flat `card` rows (the
  // Troubleshooting/FAQs nav). No inter-row gap and no per-row surface —
  // [CardListed] tells each child card to render as a compact row. Triggered by
  // `variant:"list"` OR, robustly, whenever every child is a `card` (a group of
  // cards is a menu) — so it renders tight even if the wire omits the variant.
  final childNodes = node.nodeList('children');
  final allCards =
      childNodes.isNotEmpty && childNodes.every((c) => c.type == 'card');
  if (node.stringOr('variant') == 'list' || allCards) {
    final kids = scope.buildBlocks(childNodes);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: theme.radiusLg,
        border: theme.stepCardBorderColor == null
            ? null
            : Border.all(color: theme.stepCardBorderColor!),
        boxShadow: theme.card.listShadow ?? theme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: theme.radiusLg,
        child: CardListed(
          listed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < kids.length; i++)
                if (i > 0 && theme.card.listSeparator != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: theme.card.listSeparator!),
                    ),
                    child: kids[i],
                  )
                else
                  kids[i],
            ],
          ),
        ),
      ),
    );
  }
  // A group is a card: its child headers read as item-scale sub-headings (the
  // use-case rows), not section titles. The wire still names only `header`.
  // Rows take the group's horizontal inset; a `spacer:"rule"` divider bleeds to
  // the card edge (figma: full-width dashed rule, rows padded) — so the inset is
  // applied per child, not as one outer Padding.
  final kids = scope.buildBlocks(childNodes);
  final hInset = EdgeInsets.symmetric(
    horizontal: theme.group.rowInset ?? theme.spaceMd,
  );
  // `variant:"tight"` pulls the item gap in to spaceSm — the figma troubleshooting
  // card (a title over a body, gap-8), vs the default use-case row rhythm.
  final gap =
      theme.group.gap ??
      (node.stringOr('variant') == 'tight'
          ? theme.spaceSm
          : theme.blockSpacing);
  bool isRule(BlockNode n) =>
      n.type == 'spacer' && n.stringOr('variant') == 'rule';
  final Widget content = HeadingScale(
    level: HeadingLevel.compact,
    child: Padding(
      padding: EdgeInsets.symmetric(
        vertical: theme.group.padding ?? theme.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < kids.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            if (isRule(childNodes[i]))
              kids[i]
            else
              Padding(padding: hInset, child: kids[i]),
          ],
        ],
      ),
    ),
  );
  // A featured group paints the theme's grid behind its children, clipped to the
  // group's own shape. Null gridLine -> flat, so the wire only names the emphasis
  // and the branded texture lives in the theme (like `cardGradient`).
  final featured = node.stringOr('emphasis') == 'high';
  final child = (featured && theme.gridLine != null)
      ? Stack(
          children: [
            Positioned.fill(
              child: clipShape(
                shape,
                theme.radiusLg,
                fallback: 'rounded',
                child: CustomPaint(
                  painter: GridPainter(
                    line: theme.gridLine!,
                    step: theme.gridSpacing,
                  ),
                ),
              ),
            ),
            content,
          ],
        )
      : content;
  final decoration = shapeDecoration(
    shape,
    theme.radiusLg,
    fallback: 'rounded',
    color: theme.surface,
    // A featured group fills with the theme's group gradient (the hero / use-
    // case surface); null -> flat surface, so the wire still names only the
    // emphasis and the stops live in the theme (like cardGradient).
    gradient: featured ? theme.groupGradient : null,
  );
  final side = theme.group.border;
  return DecoratedBox(
    decoration: switch ((side, decoration)) {
      (null, _) => decoration,
      (final s?, final BoxDecoration d) => d.copyWith(
        border: Border.fromBorderSide(s),
      ),
      (final s?, final ShapeDecoration d) => ShapeDecoration(
        color: d.color,
        gradient: d.gradient,
        shape: (d.shape as OutlinedBorder).copyWith(side: s),
      ),
      _ => decoration,
    },
    child: child,
  );
}

/// spacer: vertical gap of `blockSpacing * size` (size defaults to 1). With
/// `variant:"rule"` it also draws a centered hairline divider in that gap — a
/// look-only element carrying no server data, so it stays a spacer variant
/// rather than a new block type (the promotion rule: a block earns its type only
/// when it carries data AND recurs). The line color is the theme's, never wired.
Widget buildSpacer(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  // Clamp the wire `size`: a negative multiplier builds a negative SizedBox
  // height whose constraint assert fires at mount, escaping the per-block
  // try/catch; the upper cap stops an absurd value reserving a monstrous gap.
  final size = node.intOr('size', 1)!.clamp(0, 100);
  final height = theme.blockSpacing * size;
  if (node.stringOr('variant') != 'rule') return SizedBox(height: height);
  // The rule is just the hairline: the surrounding stack/list already spaces it
  // from its neighbours, so reserving another `blockSpacing` band around the line
  // stacked a triple gap around the divider (the export-data over-spacing). The
  // bare line lets the normal inter-block gap sit symmetrically above and below.
  // Dashed + full-bleed (the group renders it outside the row inset) — figma's
  // full-width dashed divider; the color is the theme's, never wired.
  return SizedBox(
    width: double.infinity,
    height: 1,
    child: CustomPaint(
      painter: _DashedLinePainter(
        theme.divider ?? theme.onSurface.withValues(alpha: 0.12),
      ),
    ),
  );
}

/// A 1px horizontal dashed hairline (figma's `border-dashed` rule). Kept here
/// with [buildSpacer] — its only caller — rather than a shared file.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter(this.color);
  final Color color;
  static const double _dash = 3, _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
