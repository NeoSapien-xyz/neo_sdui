import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_shape.dart';

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
  // Wire `shape` role (opt-in); the card defaults to the theme's squircle.
  final shape = node.stringOr('shape');
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
        // Round only the TOP corners: the image sits flush above the details,
        // and the card surface rounds the bottom. Clipping all four (the old
        // full-shape clip) notched the image's bottom mid-card.
        clipShape(
          shape,
          BorderRadius.vertical(top: theme.radiusLg.topLeft),
          fallback: 'squircle',
          child: AspectRatio(
            aspectRatio: node.ratioOr(4 / 3),
            child: ColoredBox(
              // Letterbox bars blend with the card fill, not the raw surface —
              // the two diverge the moment a theme sets a distinct cardColor.
              color: theme.resolvedCardColor,
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
          clipShape(
            shape,
            theme.radiusMd,
            fallback: 'rounded',
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

  // Wire shape overrides the card's shape family; omitted keeps the theme's
  // (squircle by default, or a theme `cardShape` override).
  final cardShape = shape != null
      ? shapeBorder(shape, theme.radiusLg, fallback: 'squircle')
      : theme.resolvedCardShape;
  final surface = _surface(theme, cardShape, content);
  if (action == null) return surface;
  return GestureDetector(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: surface,
  );
}

/// The card surface: [shape] + shadow + fill, with an optional backdrop blur
/// behind a translucent fill. Geometry values come from the theme; the wire
/// carries at most a `shape` role (already resolved into [shape] by the caller).
Widget _surface(NeoSduiTheme theme, ShapeBorder shape, Widget child) {
  final Widget box = DecoratedBox(
    decoration: ShapeDecoration(
      color: theme.resolvedCardColor,
      shape: shape,
      shadows: theme.cardShadow,
    ),
    child: child,
  );
  if (theme.backdropBlur <= 0) return box;
  return ClipPath(
    clipper: ShapeBorderClipper(shape: shape),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: theme.backdropBlur, sigmaY: theme.backdropBlur),
      child: box,
    ),
  );
}
