import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// MCP guide's palette, transcribed from the Figma "MCP" screens' variable defs.
/// Per-guide look lives here, in client data — not on the wire, not in per-guide
/// widget code (KTD11). This is the second guide (after how_to): same blocks, its
/// own [NeoSduiTheme]. Font metrics mirror the Work Sans `AppStyles` the screens
/// use; the real app injects `GoogleFonts.workSans`, so this example uses plain
/// `TextStyle`s (the family is unresolved in the widget-test binding).
final NeoSduiTheme mcpTheme = _build();

NeoSduiTheme _build() {
  const accent = Color(0xFF00F1A0); // neon green (MCP primary)
  const ink = Color(0xFF0A0A0A); // flat dark from the 226deg #2b2b2b→#070707 bg
  const white = Color(0xFFFFFFFF);
  const muted = Color(0xFF868686); // MCP muted text
  const surface = Color(0xFF202423); // card shell
  const work = 'Work Sans';

  return const NeoSduiTheme(
    accent: accent,
    onAccent: ink,
    surface: surface,
    onSurface: white,
    danger: Color(0xFFFF5A5F),
    warning: Color(0xFFFFC107), // amber troubleshooting headings
    background: ink,
    textPrimary: white,
    textMuted: muted,
    // ~16px cards throughout (Figma card radius): fold radiusMd up to match.
    radiusMd: BorderRadius.all(Radius.circular(16)),
    // Card surface: #202423 squircle + soft 4% white glow (Figma card shadow).
    cardShadow: [BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 10)],
    // Accent text (step numbers, accent headings, inline brand runs) sweeps neon
    // green. PLACEHOLDER stops — replace with the exact Figma gradient fill.
    accentGradient: LinearGradient(
      colors: [Color(0xFF2DF790), Color(0xFF00F1A0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // 24 / w500 / -1 / 1.16 (MCP screen title).
    title: TextStyle(
      fontFamily: work,
      color: white,
      fontSize: 24,
      height: 1.16,
      fontWeight: FontWeight.w500,
      letterSpacing: -1,
    ),
    // 14 / w400 / -.5 / 1.3 (MCP subtitle / muted body).
    subtitle: TextStyle(
      fontFamily: work,
      color: muted,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: -.5,
    ),
    // 16 / w400 / -.3 / 1.2 (MCP body + card title).
    body: TextStyle(
      fontFamily: work,
      color: white,
      fontSize: 16,
      height: 1.2,
      fontWeight: FontWeight.w400,
      letterSpacing: -.3,
    ),
    caption: TextStyle(
      fontFamily: work,
      color: muted,
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w400,
      letterSpacing: -.48,
    ),
  );
}
