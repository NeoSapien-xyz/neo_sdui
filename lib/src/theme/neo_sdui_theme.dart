import 'package:flutter/widgets.dart';

/// All styling, supplied by the app via the renderer constructor. Wire carries
/// no pixels; swap this object (e.g. neo_ui) to re-skin every guide.
@immutable
class NeoSduiTheme {
  const NeoSduiTheme({
    required this.background,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.cardColor,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.cardRadius,
    required this.ctaLabel,
    required this.ctaBackground,
    required this.ctaRadius,
    required this.calloutText,
    required this.calloutBackground,
    required this.stepIndex,
    required this.stepCaption,
    required this.stepAccent,
    required this.faqQuestion,
    required this.faqAnswer,
    required this.tabLabel,
    required this.tabSelected,
    required this.mediaRadius,
    required this.shimmerBase,
    required this.shimmerHighlight,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 20),
    this.blockSpacing = 24,
    this.motionDuration = const Duration(milliseconds: 200),
    this.motionCurve = Curves.easeOut,
    this.reduceMotion = false,
  });

  final Color background;
  final TextStyle title;
  final TextStyle subtitle;
  final TextStyle body;

  final Color cardColor;
  final TextStyle cardTitle;
  final TextStyle cardSubtitle;
  final BorderRadius cardRadius;

  final TextStyle ctaLabel;
  final Color ctaBackground;
  final BorderRadius ctaRadius;

  final TextStyle calloutText;
  final Color calloutBackground;

  final TextStyle stepIndex;
  final TextStyle stepCaption;
  final Color stepAccent;

  final TextStyle faqQuestion;
  final TextStyle faqAnswer;

  final TextStyle tabLabel;
  final Color tabSelected;

  final BorderRadius mediaRadius;
  final Color shimmerBase;
  final Color shimmerHighlight;

  final EdgeInsets contentPadding;
  final double blockSpacing;

  /// Motion is client-owned: bounded animations only, killable per app.
  final Duration motionDuration;
  final Curve motionCurve;
  final bool reduceMotion;

  /// Neutral dark default for tests/example. Real apps pass their own.
  factory NeoSduiTheme.fallback() {
    const white = Color(0xFFFFFFFF);
    const primary = Color(0xFF00F1A0);
    const grey = Color(0xFFB2B2B2);
    const surface = Color(0xFF202423);
    const criticalBg = Color(0xFF3A1418);
    const base = TextStyle(color: white, fontSize: 14);
    return NeoSduiTheme(
      background: const Color(0xFF0C0F0E),
      title: base.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
      subtitle: base.copyWith(fontSize: 14, color: grey),
      body: base.copyWith(fontSize: 15),
      cardColor: surface,
      cardTitle: base.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
      cardSubtitle: base.copyWith(fontSize: 13, color: grey),
      cardRadius: BorderRadius.circular(16),
      ctaLabel: base.copyWith(fontWeight: FontWeight.w500),
      ctaBackground: surface,
      ctaRadius: BorderRadius.circular(12),
      calloutText: base.copyWith(fontSize: 14),
      calloutBackground: criticalBg,
      stepIndex: base.copyWith(fontWeight: FontWeight.w600, color: primary),
      stepCaption: base.copyWith(fontSize: 15),
      stepAccent: primary,
      faqQuestion: base.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      faqAnswer: base.copyWith(fontSize: 14, color: grey),
      tabLabel: base.copyWith(fontSize: 14),
      tabSelected: primary,
      mediaRadius: BorderRadius.circular(12),
      shimmerBase: surface,
      shimmerHighlight: const Color(0xFF2C302F),
    );
  }

  NeoSduiTheme copyWith({
    Color? background,
    TextStyle? title,
    TextStyle? subtitle,
    TextStyle? body,
    Color? cardColor,
    TextStyle? cardTitle,
    TextStyle? cardSubtitle,
    BorderRadius? cardRadius,
    TextStyle? ctaLabel,
    Color? ctaBackground,
    BorderRadius? ctaRadius,
    TextStyle? calloutText,
    Color? calloutBackground,
    TextStyle? stepIndex,
    TextStyle? stepCaption,
    Color? stepAccent,
    TextStyle? faqQuestion,
    TextStyle? faqAnswer,
    TextStyle? tabLabel,
    Color? tabSelected,
    BorderRadius? mediaRadius,
    Color? shimmerBase,
    Color? shimmerHighlight,
    EdgeInsets? contentPadding,
    double? blockSpacing,
    Duration? motionDuration,
    Curve? motionCurve,
    bool? reduceMotion,
  }) {
    return NeoSduiTheme(
      background: background ?? this.background,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      cardColor: cardColor ?? this.cardColor,
      cardTitle: cardTitle ?? this.cardTitle,
      cardSubtitle: cardSubtitle ?? this.cardSubtitle,
      cardRadius: cardRadius ?? this.cardRadius,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      ctaBackground: ctaBackground ?? this.ctaBackground,
      ctaRadius: ctaRadius ?? this.ctaRadius,
      calloutText: calloutText ?? this.calloutText,
      calloutBackground: calloutBackground ?? this.calloutBackground,
      stepIndex: stepIndex ?? this.stepIndex,
      stepCaption: stepCaption ?? this.stepCaption,
      stepAccent: stepAccent ?? this.stepAccent,
      faqQuestion: faqQuestion ?? this.faqQuestion,
      faqAnswer: faqAnswer ?? this.faqAnswer,
      tabLabel: tabLabel ?? this.tabLabel,
      tabSelected: tabSelected ?? this.tabSelected,
      mediaRadius: mediaRadius ?? this.mediaRadius,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      contentPadding: contentPadding ?? this.contentPadding,
      blockSpacing: blockSpacing ?? this.blockSpacing,
      motionDuration: motionDuration ?? this.motionDuration,
      motionCurve: motionCurve ?? this.motionCurve,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}
