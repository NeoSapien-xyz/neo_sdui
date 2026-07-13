import 'package:flutter/widgets.dart';

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
    this.backdropBlur = 0,
    this.motionDuration = const Duration(milliseconds: 200),
    this.motionCurve = Curves.easeOut,
    this.reduceMotion = false,
    this.accentGradient,
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

  // Derivation (KTD11): wire sends emphasis/tone, these turn it into pixels.

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

  /// Title color by tone: accent/critical tint the baked title; else unchanged.
  TextStyle titleTone(String? tone) => switch (tone) {
        'accent' => title.copyWith(color: accent),
        'critical' => title.copyWith(color: danger),
        _ => title,
      };

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
    double? backdropBlur,
    Duration? motionDuration,
    Curve? motionCurve,
    bool? reduceMotion,
    Gradient? accentGradient,
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
      backdropBlur: backdropBlur ?? this.backdropBlur,
      motionDuration: motionDuration ?? this.motionDuration,
      motionCurve: motionCurve ?? this.motionCurve,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      accentGradient: accentGradient ?? this.accentGradient,
    );
  }
}
