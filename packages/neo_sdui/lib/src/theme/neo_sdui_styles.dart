import 'package:flutter/widgets.dart';

import 'neo_sdui_theme.dart' show NeoGlyphBuilder;

/// Per-block look knobs, one small const object per block. Each field defaults
/// to the literal its block paints today; a nullable field is one whose value
/// derives from the theme palette, and the block falls back to that derivation
/// when it is null. A theme sets only the fields a guide needs to move.

/// The segmented tab strip. Null colours fall back to the derived `tabTrack`,
/// the darkened pill, and `textPrimary`.
@immutable
class NeoTabsStyle {
  const NeoTabsStyle({
    this.trackColor,
    this.trackBorder,
    this.trackRadius,
    this.trackPadding = const EdgeInsets.all(2),
    this.gap = 0,
    this.neumorphic = true,
    this.pillColor,
    this.pillShadow = const [],
    this.pillBorder,
    this.labelStyle,
    this.unselectedWeight = FontWeight.w400,
    this.labelPadding = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    this.unselectedColor,
    this.labelMaxLines,
    this.contentGap,
  });

  /// Null -> `NeoSduiTheme.tabTrack`.
  final Color? trackColor;
  final BorderSide? trackBorder;

  /// Null -> `radiusMd`.
  final BorderRadius? trackRadius;
  final EdgeInsets trackPadding;

  /// Space between tabs.
  final double gap;

  /// False drops the track and pill inset shadows and the unselected divider.
  final bool neumorphic;

  /// Null -> the surface lightly darkened.
  final Color? pillColor;
  final List<BoxShadow> pillShadow;
  final BorderSide? pillBorder;

  /// Null -> `body`.
  final TextStyle? labelStyle;
  final FontWeight unselectedWeight;
  final EdgeInsets labelPadding;

  /// Null -> `textPrimary`.
  final Color? unselectedColor;

  /// Null -> no cap.
  final int? labelMaxLines;

  /// Strip-to-content gap. Null -> `spaceMd`.
  final double? contentGap;
}

/// The `card` block (picker card and list rows).
@immutable
class NeoCardStyle {
  const NeoCardStyle({
    this.thumbRadius,
    this.titleGap = 8,
    this.actionGap = 8,
    this.listSeparator,
    this.listIconColor,
    this.listIconGap = 12,
    this.listCaret,
    this.listCaretGap = 8,
    this.shadow,
    this.listShadow,
    this.pickerLineHeight,
  });

  /// Null -> `radiusMd`.
  final BorderRadius? thumbRadius;

  /// Name-to-description gap.
  final double titleGap;

  /// Copy-to-action-label gap.
  final double actionGap;

  /// Null -> no separator between list rows.
  final BorderSide? listSeparator;

  /// Null -> the row icon's tone colour.
  final Color? listIconColor;
  final double listIconGap;

  /// Null -> the `›` text caret.
  final NeoGlyphBuilder? listCaret;
  final double listCaretGap;

  /// Null -> `cardShadow`.
  final List<BoxShadow>? shadow;

  /// Null -> `cardShadow`.
  final List<BoxShadow>? listShadow;

  /// Line-height multiplier for the picker card's name and description. Null ->
  /// inherit the ambient text height.
  final double? pickerLineHeight;
}

/// The `group` block (the shared card around use-case rows and list rows).
@immutable
class NeoGroupStyle {
  const NeoGroupStyle({this.border, this.rowInset, this.padding, this.gap});

  /// The plain group's outline. Null -> no border, as today; the list-card
  /// variant keeps its own `stepCardBorderColor` hairline either way.
  final BorderSide? border;

  /// Horizontal row inset. Null -> `spaceMd`.
  final double? rowInset;

  /// Vertical padding. Null -> `spaceMd`.
  final double? padding;

  /// Gap between rows. Null -> `blockSpacing` (`spaceSm` for a tight group).
  final double? gap;
}

/// The `steps` block: the compact chip strip and the carded vertical step.
@immutable
class NeoStepsStyle {
  const NeoStepsStyle({
    this.chipGap,
    this.chipBorder,
    this.badgeStyle,
    this.chipLabelStyle,
    this.cardShadow,
    this.cardGap = 12,
    this.imageBackdrop,
    this.labelStyle,
    this.labelGap = 4,
    this.instructionStyle,
    this.labelNumberOffset = -1,
    this.labelSuffix = ':',
    this.autoLinkUrls = true,
  });

  /// Gap between chips. Null -> `spaceMd`.
  final double? chipGap;

  /// Null -> `stepCardBorderColor`.
  final Color? chipBorder;

  /// Null -> `caption` at 11 in the tone colour.
  final TextStyle? badgeStyle;

  /// Null -> `body`.
  final TextStyle? chipLabelStyle;

  /// Null -> `cardShadow`.
  final List<BoxShadow>? cardShadow;

  /// Gap between carded steps.
  final double cardGap;

  /// Fill behind a step image. Null -> none.
  final Color? imageBackdrop;

  /// The "Step n:" label. Null -> `body` at weight 500.
  final TextStyle? labelStyle;

  /// Label-to-instruction gap.
  final double labelGap;

  /// Null -> `body` in `textPrimary` at weight 500.
  final TextStyle? instructionStyle;

  /// Added to the 1-based step number in the label (today's labels are 0-based).
  final int labelNumberOffset;

  /// Text after the number in the label.
  final String labelSuffix;

  /// Underline bare URLs in a string caption.
  final bool autoLinkUrls;
}

/// The `callout` block.
@immutable
class NeoCalloutStyle {
  const NeoCalloutStyle({
    this.fill,
    this.toneSurfaces = const {},
    this.border,
    this.toneBorders = const {},
    this.radius,
    this.padding,
    this.emphasizeFirstBullet = true,
  });

  /// Null -> `surface` (or the tone surface for `critical`).
  final Color? fill;

  /// Tone name -> surface, winning over [fill] and the derived tint for that tone.
  final Map<String, Color> toneSurfaces;
  final BorderSide? border;

  /// Tone name -> border, winning over [border] for that tone.
  final Map<String, BorderSide> toneBorders;

  /// Null -> `radiusLg`.
  final BorderRadius? radius;

  /// Null -> `cardPadding`.
  final EdgeInsets? padding;

  /// First bullet in full white, the rest dimmed.
  final bool emphasizeFirstBullet;
}

/// The `faq` block.
@immutable
class NeoFaqStyle {
  const NeoFaqStyle({
    this.itemDecoration,
    this.itemGap = 0,
    this.questionPadding = const EdgeInsets.symmetric(vertical: 20),
    this.caretGlyph,
    this.openTurns = 0.25,
    this.caretColor,
    this.answerStyle,
    this.answerPadding,
  });

  /// Null -> none (the hairline divider between items is the block's own).
  final Decoration? itemDecoration;
  final double itemGap;
  final EdgeInsets questionPadding;

  /// Null -> the `›` text caret.
  final NeoGlyphBuilder? caretGlyph;

  /// Caret rotation when open, in turns.
  final double openTurns;

  /// Closed-state caret colour. Null -> `textPrimary`.
  final Color? caretColor;

  /// Null -> `body`.
  final TextStyle? answerStyle;

  /// Null -> `spaceSm` above the answer.
  final EdgeInsets? answerPadding;
}

/// The `header` block.
@immutable
class NeoHeaderStyle {
  const NeoHeaderStyle({
    this.subtitleGap = 4,
    this.compactIconSize,
    this.compactIconGap,
    this.subheadingGap,
    this.subheadingTopInset = 0,
    this.compactLineHeight,
    this.compactSubtitleGap,
  });

  /// Title-to-subtitle gap.
  final double subtitleGap;

  /// Leading icon size in a compact (in-card) header. Null -> the title's size.
  final double? compactIconSize;

  /// Null -> `spaceSm`.
  final double? compactIconGap;

  /// Null -> [subtitleGap].
  final double? subheadingGap;
  final double subheadingTopInset;

  /// Line-height multiplier for a compact (in-card) header's title and subtitle.
  /// Null -> inherit the ambient text height.
  final double? compactLineHeight;

  /// Null -> [subtitleGap].
  final double? compactSubtitleGap;
}

/// The accordion block.
@immutable
class NeoAccordionStyle {
  const NeoAccordionStyle({
    this.chevron,
    this.chevronSize = 16,
    this.headPadding = const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    this.headGap = 12,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 4, 16, 20),
  });

  /// Null -> the package-drawn chevron.
  final NeoGlyphBuilder? chevron;
  final double chevronSize;
  final EdgeInsets headPadding;

  /// Title-to-chevron gap.
  final double headGap;
  final EdgeInsets bodyPadding;
}

/// The link row under a step (a label plus a copy button).
@immutable
class NeoLinkRowStyle {
  const NeoLinkRowStyle({
    this.border,
    this.fill,
    this.iconColor,
    this.linkStyle,
    this.topPadding = 10,
    this.gap = 8,
    this.copySize = 28,
    this.copyGlyph,
    this.checkGlyph,
  });

  /// Null -> `onSurface` at 8%.
  final Color? border;

  /// Null -> `onSurface` at 3%.
  final Color? fill;

  /// Null -> `textMuted`.
  final Color? iconColor;

  /// Null -> `caption` in accent.
  final TextStyle? linkStyle;
  final double topPadding;

  /// Label-to-button gap.
  final double gap;

  /// Copy button side.
  final double copySize;

  /// Null -> the package-drawn copy glyph.
  final NeoGlyphBuilder? copyGlyph;

  /// Null -> the package-drawn check glyph.
  final NeoGlyphBuilder? checkGlyph;
}
