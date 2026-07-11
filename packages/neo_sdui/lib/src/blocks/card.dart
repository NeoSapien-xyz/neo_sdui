import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';

/// card: title + optional subtitle + optional thumbnail + optional action, drawn
/// on the theme's card surface (shape/shadow/fill/padding — all client-owned,
/// none on the wire). One block, three arrangements chosen by field presence:
///
///  - `variant:"tile"` + `thumb`  -> image-top card (how_to): full-width
///    thumbnail (contained, shape-clipped) above a title + caret row.
///  - `thumb` alone                -> compact row (MCP client-picker): small
///    leading thumbnail + title/subtitle + caret.
///  - neither                      -> title/subtitle + caret (footer nav).
Widget buildCard(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final subtitle = node.stringOr('subtitle');
  final action = node.stringOr('action');
  final thumb = node.stringOr('thumb');
  final tile = node.stringOr('variant') == 'tile';
  final titleStyle =
      theme.body.copyWith(color: theme.onSurface, fontWeight: FontWeight.w500);

  final details = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(node.stringOr('title', '')!, style: titleStyle),
            if (subtitle != null) Text(subtitle, style: theme.caption),
          ],
        ),
      ),
      if (action != null) ...[
        const SizedBox(width: 4),
        Text('›', style: titleStyle),
      ],
    ],
  );

  final Widget content;
  if (tile && thumb != null) {
    content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipPath(
          clipper: ShapeBorderClipper(shape: theme.resolvedCardShape),
          child: AspectRatio(
            aspectRatio: _ratioOf(node),
            child: ColoredBox(
              color: theme.surface,
              child: Image.network(
                thumb,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        Padding(padding: theme.cardPadding, child: details),
      ],
    );
  } else if (thumb != null) {
    content = Padding(
      padding: theme.cardPadding,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: theme.radiusMd,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: theme.surface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: details),
        ],
      ),
    );
  } else {
    content = Padding(padding: theme.cardPadding, child: details);
  }

  final surface = _surface(theme, content);
  if (action == null) return surface;
  return GestureDetector(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: surface,
  );
}

/// The card surface: shape + shadow + fill, with an optional backdrop blur behind
/// a translucent fill. All values come from the theme; the wire carries none.
Widget _surface(NeoSduiTheme theme, Widget child) {
  final Widget box = DecoratedBox(
    decoration: ShapeDecoration(
      color: theme.resolvedCardColor,
      shape: theme.resolvedCardShape,
      shadows: theme.cardShadow,
    ),
    child: child,
  );
  if (theme.backdropBlur <= 0) return box;
  return ClipPath(
    clipper: ShapeBorderClipper(shape: theme.resolvedCardShape),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: theme.backdropBlur, sigmaY: theme.backdropBlur),
      child: box,
    ),
  );
}

/// Tile thumbnail ratio: explicit `ratio`, else raw `width`/`height`, else 4:3
/// (the how_to Figma thumbnail; the other confirmed option is 2:1).
double _ratioOf(BlockNode node) {
  final ratio = node.fields['ratio'];
  if (ratio is num && ratio > 0) return ratio.toDouble();
  final w = node.intOr('width'), h = node.intOr('height');
  if (w != null && h != null && h > 0) return w / h;
  return 4 / 3;
}
