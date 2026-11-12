import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import '_icon.dart';
import '_motion.dart';
import '_shape.dart';

/// Marks a subtree where cards are rows of a shared list container (a `group`
/// with `variant:"list"` — the Troubleshooting/FAQs nav). A listed card drops
/// its own surface/shadow and renders as a compact `icon + label + caret` row,
/// so the group's one card holds them all. The wire still names only `card`.
class CardListed extends InheritedWidget {
  const CardListed({required this.listed, required super.child, super.key});
  final bool listed;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardListed>()?.listed ?? false;
  @override
  bool updateShouldNotify(CardListed old) => listed != old.listed;
}

/// card: title + optional subtitle + optional thumbnail + optional action, drawn
/// on the theme's card surface (shape/shadow/fill/padding — all client-owned,
/// none on the wire). Four arrangements — three chosen by field presence, one by
/// ambient render context:
///
///  - `variant:"tile"` + `thumb`  -> image-top card (how_to): full-width
///    thumbnail (contained, shape-clipped) above a title + caret row.
///  - `thumb` alone                -> compact row (MCP client-picker): small
///    leading thumbnail + title/subtitle + caret.
///  - neither                      -> title/subtitle + caret (footer nav).
///  - inside a `variant:"list"` group (`CardListed.of(context)`) -> a flat
///    icon + label + caret row with no surface, regardless of field presence.
Widget buildCard(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final subtitle = node.stringOr('subtitle');
  final action = node.stringOr('action');
  // Optional trailing affordance label ("Open Guide →"): when set on a tappable
  // card it replaces the default `›` caret, painted in the accent role. The wire
  // carries the words; the accent color/gradient is the theme's.
  final actionLabel = node.stringOr('actionLabel');
  final thumb = node.stringOr('thumb');
  final tile = node.stringOr('variant') == 'tile';
  // A *featured* card (`emphasis:"high"`) takes the theme's card gradient; every
  // other card stays the flat surface. Null gradient -> featured falls back to
  // flat, so the wire names emphasis and the theme owns whether it's a gradient.
  final featuredGradient = node.stringOr('emphasis') == 'high'
      ? theme.cardGradient
      : null;
  // The icon-row picker card (a `thumb` card that isn't a `tile`) is figma's
  // neumorphic card: the theme's card gradient + hairline border + soft glow,
  // not the flat surface every other card keeps.
  final pickerCard = thumb != null && node.stringOr('variant') != 'tile';
  final surfaceGradient =
      featuredGradient ?? (pickerCard ? theme.cardGradient : null);
  // Wire `shape` role (opt-in); the card defaults to the theme's squircle.
  final shape = node.stringOr('shape');
  final titleStyle = theme.resolvedRowTitle;

  // Inside a `variant:"list"` group: a flat icon + label + caret row, no surface.
  if (CardListed.of(context)) {
    return _listedCard(context, scope, theme, node, titleStyle);
  }

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
        // Labelled affordance ("Open Guide →") in the accent role, else the
        // default caret. The caret branch is untouched, so cards without a label
        // regenerate no goldens.
        if (actionLabel != null)
          neoText(
            theme,
            actionLabel,
            theme.emphasize(theme.caption),
            tone: 'accent',
          )
        else
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
    // Figma picker card: 40px icon, gap 10, title over a muted subtitle at the
    // *same* scale (the shared `titleStyle` — the picker's subtitle is a second
    // line of the title, not a caption), a flat-accent "Open Guide" — everything
    // vertically centered in the row (a Row centers by default), not top-aligned
    // like the shared `details`.
    final pickerTitle = titleStyle.copyWith(
      height: theme.card.pickerLineHeight,
    );
    content = Padding(
      padding: theme.cardPadding,
      child: Row(
        children: [
          clipShape(
            shape,
            theme.card.thumbRadius ?? theme.radiusMd,
            fallback: 'rounded',
            child: SizedBox(
              width: 40,
              height: 40,
              child: Image.network(
                thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(color: theme.surface),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(node.stringOr('title', '')!, style: pickerTitle),
                if (subtitle != null) ...[
                  SizedBox(height: theme.card.titleGap),
                  Text(
                    subtitle,
                    style: pickerTitle.copyWith(color: theme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null) ...[
            SizedBox(width: theme.card.actionGap),
            // Flat accent, not the accent gradient — the same affordance label
            // the `details` row paints, on the theme's caption role.
            Text(
              actionLabel,
              style: theme
                  .emphasize(theme.caption)
                  .copyWith(color: theme.accent),
            ),
          ],
        ],
      ),
    );
  } else {
    content = Padding(padding: theme.cardPadding, child: details);
  }

  // A recognized wire shape overrides the card's shape family; omitted OR an
  // unrecognized token keeps the theme's default (squircle, or a `cardShape`
  // override) — so a typo degrades to the default, never silently to a rounded
  // rect (the card is the one block whose default is squircle).
  final cardShape = switch (shape) {
    'squircle' => RoundedSuperellipseBorder(borderRadius: theme.radiusLg),
    'rounded' => RoundedRectangleBorder(borderRadius: theme.radiusLg),
    _ => theme.resolvedCardShape,
  };
  final surface = _surface(
    theme,
    cardShape,
    content,
    gradient: surfaceGradient,
    shadows: pickerCard ? theme.card.shadow : null,
  );
  if (action == null) return surface;
  return PressScale(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: surface,
  );
}

/// A listed card: a compact `icon + label + caret` nav row with no surface of
/// its own (the enclosing `variant:"list"` group draws the shared card). Leading
/// `icon` is a theme glyph role; the caret is a muted chevron. Tappable when the
/// wire sets an `action`.
Widget _listedCard(
  BuildContext context,
  NeoSduiScope scope,
  NeoSduiTheme theme,
  BlockNode node,
  TextStyle titleStyle,
) {
  final action = node.stringOr('action');
  final subtitle = node.stringOr('subtitle');
  // A themed icon colour replaces the tone colour.
  final icon = leadingIcon(
    theme,
    node.stringOr('icon'),
    node.stringOr('tone'),
    size: 20,
    color: theme.card.listIconColor,
  );
  final row = Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Row(
      children: [
        if (icon != null) ...[icon, SizedBox(width: theme.card.listIconGap)],
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
          SizedBox(width: theme.card.listCaretGap),
          if (theme.card.listCaret case final caret?)
            caret(20, theme.textMuted)
          else
            Text('›', style: titleStyle.copyWith(color: theme.textMuted)),
        ],
      ],
    ),
  );
  if (action == null) return row;
  return PressScale(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    // A row inside a shared card dips shallower than a card of its own — it has
    // no edge to move against, so a card's depth would read as a wobble.
    scale: 0.994,
    child: row,
  );
}

/// The card surface: [shape] + shadow + fill, with an optional backdrop blur
/// behind a translucent fill. A featured card passes [gradient] (the theme's
/// `cardGradient`) and fills with it instead of the flat card color. Geometry
/// values come from the theme; the wire carries at most a `shape`/`emphasis`
/// role (already resolved into [shape]/[gradient] by the caller).
Widget _surface(
  NeoSduiTheme theme,
  ShapeBorder shape,
  Widget child, {
  Gradient? gradient,
  List<BoxShadow>? shadows,
}) {
  // A gradient (neumorphic) card also takes figma's hairline border; a flat card
  // keeps its borderless shape, byte-identical to before.
  final hairline = gradient != null && theme.stepCardBorderColor != null;
  final shaped = hairline
      ? _withSide(shape, BorderSide(color: theme.stepCardBorderColor!))
      : shape;
  final Widget box = DecoratedBox(
    decoration: ShapeDecoration(
      color: gradient == null ? theme.resolvedCardColor : null,
      gradient: gradient,
      shape: shaped,
      shadows: shadows ?? theme.cardShadow,
    ),
    // The hairline takes layout space like a CSS border (box-sizing: border-box
    // adds it to the card), so the card is its padding plus the border.
    child: hairline
        ? Padding(padding: const EdgeInsets.all(1), child: child)
        : child,
  );
  if (theme.backdropBlur <= 0) return box;
  return ClipPath(
    clipper: ShapeBorderClipper(shape: shaped),
    child: BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: theme.backdropBlur,
        sigmaY: theme.backdropBlur,
      ),
      child: box,
    ),
  );
}

/// The card shape with a hairline [side] added — used for the neumorphic
/// (gradient) card's figma border. Only the two rounded families the card uses.
ShapeBorder _withSide(ShapeBorder shape, BorderSide side) => switch (shape) {
  RoundedSuperellipseBorder b => RoundedSuperellipseBorder(
    borderRadius: b.borderRadius,
    side: side,
  ),
  RoundedRectangleBorder b => RoundedRectangleBorder(
    borderRadius: b.borderRadius,
    side: side,
  ),
  _ => shape,
};
