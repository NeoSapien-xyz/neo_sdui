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

/// column: children stacked vertically with themed gaps.
Widget buildColumn(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  return _stack(scope.buildBlocks(node.nodeList('children')), scope.theme.blockSpacing);
}

/// group: children stacked inside a themed surface. A *featured* group
/// (`emphasis:"high"`) also paints the theme's grid texture behind its children.
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
        boxShadow: theme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: theme.radiusLg,
        child: CardListed(
          listed: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: kids,
          ),
        ),
      ),
    );
  }
  // A group is a card: its child headers read as item-scale sub-headings (the
  // use-case rows), not section titles. The wire still names only `header`.
  final Widget content = HeadingScale(
    compact: true,
    child: Padding(
      padding: EdgeInsets.all(theme.spaceMd),
      child:
          _stack(scope.buildBlocks(node.nodeList('children')), theme.blockSpacing),
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
                  painter: GridPainter(line: theme.gridLine!, step: theme.gridSpacing),
                ),
              ),
            ),
            content,
          ],
        )
      : content;
  return DecoratedBox(
    decoration: shapeDecoration(
      shape,
      theme.radiusLg,
      fallback: 'rounded',
      color: theme.surface,
      // A featured group fills with the theme's group gradient (the hero / use-
      // case surface); null -> flat surface, so the wire still names only the
      // emphasis and the stops live in the theme (like cardGradient).
      gradient: featured ? theme.groupGradient : null,
    ),
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
  return SizedBox(
    height: height,
    child: Center(
      child: Container(
        height: 1,
        color: theme.divider ?? theme.onSurface.withValues(alpha: 0.12),
      ),
    ),
  );
}

Widget _stack(List<Widget> kids, double gap) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < kids.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          kids[i],
        ],
      ],
    );
