import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// how_to's palette, transcribed from neo's `AppColors`/`AppStyles` — the values
/// the real app hands the renderer (neo_sdui depends on neither). Font metrics
/// mirror the Work Sans `AppStyles` entries the how_to page uses; the real app
/// injects `GoogleFonts.workSans`, so this example uses plain `TextStyle`s (the
/// family is unresolved in the widget-test binding, the metrics stay faithful).
///
/// Per-guide look lives here, in client data — not on the wire, not in per-guide
/// widget code. A second guide (MCP) gets its own `NeoSduiTheme`; the blocks are
/// unchanged.
final NeoSduiTheme howToTheme = _build();

NeoSduiTheme _build() {
  const accent = Color(0xFF00F1A0); // AppColors.primary500
  const ink = Color(0xFF0C0F0E); // AppColors.bottomSheetBackground
  const white = Color(0xFFFFFFFF);
  const grey = Color(0xFFB2B2B2); // how-to-subtitle grey (AppColors.background100)
  const surface = Color(0xFF202423); // card shell (AppColors.shareCardBackground)
  const work = 'Work Sans';

  return const NeoSduiTheme(
    accent: accent,
    onAccent: ink,
    surface: surface,
    onSurface: white,
    danger: Color(0xFFFF5A5F),
    warning: Color(0xFFFFD166),
    background: ink,
    textPrimary: white,
    textMuted: grey,
    // Card surface: #202423 squircle (default radiusLg 16) + neo's soft 4% white
    // glow — the how_to card's ShapeDecoration, transcribed from _HowToCard.
    cardShadow: [BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 10)],
    // AppStyles.h5 — 24 / w500 / -1 / 1.5 (how-to-title; sheet title tinted accent).
    title: TextStyle(
      fontFamily: work,
      color: white,
      fontSize: 24,
      height: 1.5,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
    ),
    // AppStyles.h8w400 — 14 / w400 / -.5 / 1.3125 (how-to-subtitle).
    subtitle: TextStyle(
      fontFamily: work,
      color: grey,
      fontSize: 14,
      height: 1.3125,
      fontWeight: FontWeight.w400,
      letterSpacing: -.5,
    ),
    // AppStyles.h7w400 — 16 / w400 / -.3 / 1.125 (how-to-sheet-desc + card title).
    body: TextStyle(
      fontFamily: work,
      color: white,
      fontSize: 16,
      height: 1.125,
      fontWeight: FontWeight.w400,
      letterSpacing: -.3,
    ),
    caption: TextStyle(
      fontFamily: work,
      color: grey,
      fontSize: 14,
      height: 1.3125,
      fontWeight: FontWeight.w400,
      letterSpacing: -.5,
    ),
  );
}
