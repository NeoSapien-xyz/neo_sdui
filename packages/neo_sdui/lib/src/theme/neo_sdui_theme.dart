import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

/// Default named-icon glyphs. The wire names a role ("sparkle"); this resolves
/// it to a glyph. A client swaps its own set (its AppIcons); an unmapped name
/// draws nothing — graceful, like a null [NeoSduiTheme.accentGradient].
const Map<String, IconData> kDefaultIcons = {
  'sparkle': Icons.auto_awesome,
  'download': Icons.download,
  'info': Icons.info_outline,
  'check': Icons.check_circle,
  'warning': Icons.warning_amber_rounded,
};

/// The built-in accent tone names [NeoSduiTheme.accentFor] resolves even without
/// a theme-declared `accents.<name>` entry. Exported so the role-drift lint reads
/// one list instead of hand-duplicating it; keep in sync with `accentFor`'s switch.
const Set<String> kBuiltinAccentTones = {'accent', 'critical'};

/// One accent *role* the wire can name via `tone` — a flat [color] and an
/// optional [gradient] painted over the glyphs when set (null → flat, like a
/// null `accentGradient`). The primary accent is the theme's `accent`/
/// `accentGradient`; extra hues (a second brand accent, a distinct step-count
/// color) live as named entries in [NeoSduiTheme.accents], e.g. `"brand"`.
@immutable
class NeoAccent {
  const NeoAccent(this.color, [this.gradient]);
  final Color color;
  final Gradient? gradient;
}

/// The look authority (a HostConfig analog). A small role palette + type scale +
/// derivation helpers. Blocks read roles and let this compute their look — the
/// wire never carries pixels. The app builds this from its own AppStyles/
/// AppColors today; a future neo_ui rebuilds the same palette with the same wire.
@immutable
class NeoSduiTheme {
  const NeoSduiTheme({
    required this.accent,
    required this.onAccent,
    required this.surface,
    required this.onSurface,
    required this.danger,
    required this.warning,
    required this.background,
    required this.textPrimary,
    required this.textMuted,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.caption,
    this.mono = const TextStyle(
      fontFamilyFallback: ['Menlo', 'Courier New', 'monospace'],
      fontSize: 13,
      height: 1.4,
    ),
    this.radiusSm = const BorderRadius.all(Radius.circular(8)),
    this.radiusMd = const BorderRadius.all(Radius.circular(12)),
    this.radiusLg = const BorderRadius.all(Radius.circular(16)),
    this.spaceSm = 8,
    this.spaceMd = 16,
    this.spaceLg = 24,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 20),
    this.blockSpacing = 24,
    this.cardColor,
    this.cardShape,
    this.cardShadow = const [],
    this.cardPadding = const EdgeInsets.all(18),
    this.cardGradient,
    this.gridLine,
    this.gridSpacing = 24,
    this.groupGradient,
    this.divider,
    this.backdropBlur = 0,
    this.motionDuration = const Duration(milliseconds: 200),
    this.motionCurve = Curves.easeOut,
    this.reduceMotion = false,
    this.accentGradient,
    this.backgroundGradient,
    this.ctaGradient,
    this.accents = const {},
    this.icons = kDefaultIcons,
  });

  // Role colors.
  final Color accent;
  final Color onAccent;
  final Color surface;
  final Color onSurface;
  final Color danger;
  final Color warning;
  final Color background;
  final Color textPrimary;
  final Color textMuted;

  // Type scale (colors baked to a sensible default; blocks override for a role).
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle body;
  final TextStyle caption;

  /// Monospace style for the `code` block's content — commands, URLs, config.
  /// Color is baked to a default; the block overrides it for the textPrimary
  /// role, same as the other type-scale slots.
  final TextStyle mono;

  // Scales.
  final BorderRadius radiusSm;
  final BorderRadius radiusMd;
  final BorderRadius radiusLg;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final EdgeInsets contentPadding;
  final double blockSpacing;

  // Card surface treatment — the pixels of an elevated surface, client-owned and
  // never on the wire (the Adaptive Cards HostConfig `containerStyles` analog).
  // Defaults resolve to neo's how_to card: a squircle over the `surface` role.
  // A guide's card look is a matter of the theme handed in, not per-guide code.
  final Color? cardColor;
  final ShapeBorder? cardShape;
  final List<BoxShadow> cardShadow;
  final EdgeInsets cardPadding;

  /// Gradient surface for a *featured* card (`emphasis:"high"` on the wire) —
  /// client-owned stops, like [accentGradient]/[cardShadow]. Null → a featured
  /// card stays the flat [resolvedCardColor], byte-identical to a plain card, so
  /// a theme that sets no card gradient renders every card flat. The wire only
  /// ever names the emphasis; the stops live here (KTD9).
  final Gradient? cardGradient;

  /// Faint grid texture painted over a *featured* container (a `group` with
  /// `emphasis:"high"`) — the NeoSapien branded surface. Client-owned, like
  /// [cardGradient]; the wire only ever names the emphasis, never the texture.
  /// Null -> no grid, the container stays the flat `surface`. [gridSpacing] is
  /// the px gap between grid lines.
  final Color? gridLine;
  final double gridSpacing;

  /// Gradient fill for a *featured* group (`emphasis:"high"`) — the section
  /// container behind the [gridLine] texture (the hero card, the use-case
  /// surface). Like [cardGradient] but for the `group` block. Null → the
  /// featured group stays the flat `surface` (still painted with the grid, if
  /// any), byte-identical to before. The wire only ever names the emphasis.
  final Gradient? groupGradient;

  /// Hairline color for a `spacer` with `variant:"rule"` (a divider line).
  /// Null → a faint line derived from `onSurface`. Client-owned, like every
  /// other pixel; the wire only names the variant, never the color.
  final Color? divider;

  final double backdropBlur;

  Color get resolvedCardColor => cardColor ?? surface;
  ShapeBorder get resolvedCardShape =>
      cardShape ?? RoundedSuperellipseBorder(borderRadius: radiusLg);

  // Motion is client-owned: bounded animations only, killable per app (KTD9).
  final Duration motionDuration;
  final Curve motionCurve;
  final bool reduceMotion;

  /// Gradient the `accent` text role paints with — step numbers, accent-toned
  /// headings, and inline `tone:"accent"` runs (e.g. a brand word inside a
  /// sentence). Client-owned stops, like `cardShadow`; the wire only ever names
  /// `accent`, never gradient stops (KTD9). Null -> accent text stays the flat
  /// `accent` color, byte-identical to the pre-gradient render.
  final Gradient? accentGradient;

  /// Gradient painted behind the whole screen (the app backdrop). Client-owned
  /// stops, like [accentGradient]. Null -> the backdrop stays the flat
  /// [background] color, byte-identical to the pre-gradient render. The wire
  /// never carries a backdrop gradient; only the theme does (KTD9).
  final Gradient? backgroundGradient;

  /// Gradient fill for a *featured* cta (`emphasis:"high"`) — the branded button
  /// surface. Client-owned stops, like [accentGradient]/[cardGradient]. Null ->
  /// a high-emphasis cta stays the flat `accent` fill, byte-identical to before.
  /// The wire only ever names the emphasis; the stops live here (KTD9).
  final Gradient? ctaGradient;

  /// Extra named accent roles beyond the primary `accent`/`critical`, keyed by
  /// the `tone` name the wire uses (e.g. `"brand"`). Lets one screen carry two
  /// distinct accent hues — a title gradient and a different step-count gradient
  /// — while the wire still only names roles. Client-owned; the default is empty
  /// (only `accent`/`critical` exist), so this is inert until a theme adds a hue.
  final Map<String, NeoAccent> accents;

  /// Named-icon → glyph map (client-owned, like [accentGradient]). The wire names
  /// an icon role ("sparkle", "download"); this resolves it to a glyph. A client
  /// swaps its own set; an unmapped name resolves to null and no icon is drawn.
  final Map<String, IconData> icons;

  // Derivation (KTD11): wire sends emphasis/tone, these turn it into pixels.

  /// The glyph for a wire icon name, or null when unnamed/unmapped (draw nothing).
  IconData? iconFor(String? name) => name == null ? null : icons[name];

  /// The accent role a `tone` names — a named [accents] entry first (so a theme
  /// can add or override hues), then the built-in `accent`/`critical`. Null for
  /// no/unknown tone → the text stays its default (non-accent) look.
  NeoAccent? accentFor(String? tone) {
    if (tone == null) return null;
    final named = accents[tone];
    if (named != null) return named;
    // The cases here are the [kBuiltinAccentTones] set — keep the two in sync.
    return switch (tone) {
      'accent' => NeoAccent(accent, accentGradient),
      'critical' => NeoAccent(danger),
      _ => null,
    };
  }

  /// The flat role color a `tone` names, for tinting an icon or accent glyph;
  /// falls back to onSurface for no/unknown tone.
  Color toneColor(String? tone) => accentFor(tone)?.color ?? onSurface;

  /// Fill behind a cta by emphasis: high=accent, normal=surface, low=none.
  Color fill(String? emphasis) => switch (emphasis) {
        'high' => accent,
        'low' => const Color(0x00000000),
        _ => surface,
      };

  /// Foreground on that fill: high=onAccent, normal=onSurface, low=accent.
  Color onFill(String? emphasis) => switch (emphasis) {
        'high' => onAccent,
        'low' => accent,
        _ => onSurface,
      };

  /// Callout surface by tone: neutral=surface, accent/critical=tinted.
  Color toneSurface(String? tone) => switch (tone) {
        'accent' => Color.alphaBlend(accent.withValues(alpha: 0.16), surface),
        'critical' => Color.alphaBlend(danger.withValues(alpha: 0.16), surface),
        _ => surface,
      };

  /// Body text muted when emphasis is low, else primary.
  TextStyle bodyEmphasis(String? emphasis) =>
      emphasis == 'low' ? body.copyWith(color: textMuted) : body;

  /// Title color by tone: any accent role (named or built-in) tints the baked
  /// title; no/unknown tone leaves it unchanged.
  TextStyle titleTone(String? tone) {
    final a = accentFor(tone);
    return a == null ? title : title.copyWith(color: a.color);
  }

  Color get shimmerBase => surface;
  Color get shimmerHighlight =>
      Color.alphaBlend(onSurface.withValues(alpha: 0.08), surface);

  /// Neutral dark default for tests/example. Real apps pass their own palette.
  factory NeoSduiTheme.fallback() {
    const white = Color(0xFFFFFFFF);
    const grey = Color(0xFFB2B2B2);
    const ink = Color(0xFF0C0F0E);
    const base = TextStyle(color: white, fontSize: 14);
    return NeoSduiTheme(
      accent: const Color(0xFF00F1A0),
      onAccent: ink,
      surface: const Color(0xFF202423),
      onSurface: white,
      danger: const Color(0xFFFF5A5F),
      warning: const Color(0xFFFFD166),
      background: ink,
      textPrimary: white,
      textMuted: grey,
      title: base.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      subtitle: base.copyWith(fontSize: 14, color: grey),
      body: base.copyWith(fontSize: 15),
      caption: base.copyWith(fontSize: 13, color: grey),
    );
  }

  NeoSduiTheme copyWith({
    Color? accent,
    Color? onAccent,
    Color? surface,
    Color? onSurface,
    Color? danger,
    Color? warning,
    Color? background,
    Color? textPrimary,
    Color? textMuted,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    TextStyle? caption,
    TextStyle? mono,
    BorderRadius? radiusSm,
    BorderRadius? radiusMd,
    BorderRadius? radiusLg,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    EdgeInsets? contentPadding,
    double? blockSpacing,
    Color? cardColor,
    ShapeBorder? cardShape,
    List<BoxShadow>? cardShadow,
    EdgeInsets? cardPadding,
    Gradient? cardGradient,
    Color? gridLine,
    double? gridSpacing,
    Gradient? groupGradient,
    Color? divider,
    double? backdropBlur,
    Duration? motionDuration,
    Curve? motionCurve,
    bool? reduceMotion,
    Gradient? accentGradient,
    Gradient? backgroundGradient,
    Gradient? ctaGradient,
    Map<String, NeoAccent>? accents,
    Map<String, IconData>? icons,
  }) {
    return NeoSduiTheme(
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      background: background ?? this.background,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      caption: caption ?? this.caption,
      mono: mono ?? this.mono,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      contentPadding: contentPadding ?? this.contentPadding,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      cardColor: cardColor ?? this.cardColor,
      cardShape: cardShape ?? this.cardShape,
      cardShadow: cardShadow ?? this.cardShadow,
      cardPadding: cardPadding ?? this.cardPadding,
      cardGradient: cardGradient ?? this.cardGradient,
      gridLine: gridLine ?? this.gridLine,
      gridSpacing: gridSpacing ?? this.gridSpacing,
      groupGradient: groupGradient ?? this.groupGradient,
      divider: divider ?? this.divider,
      backdropBlur: backdropBlur ?? this.backdropBlur,
      motionDuration: motionDuration ?? this.motionDuration,
      motionCurve: motionCurve ?? this.motionCurve,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      accentGradient: accentGradient ?? this.accentGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      ctaGradient: ctaGradient ?? this.ctaGradient,
      accents: accents ?? this.accents,
      icons: icons ?? this.icons,
    );
  }
}
