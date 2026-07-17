import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import '_icon.dart';
import '_shape.dart';

/// callout: optional leading `icon` + title + a muted line list — the figma
/// "use case" card (an accent star + accent title over the plain `surface`, a
/// muted body). `tone:accent` tints the icon + title (the accent gradient when
/// the theme sets one), NOT the box: only `tone:critical` tints its surface (a
/// genuine red warning). Title and each `bullets` entry are `string-or-runs`, so
/// an inline accent phrase (e.g. a gradient "from NeoSapien") rides a bullet.
Widget buildCallout(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final tone = node.stringOr('tone');
  final title = node.fields['title'];
  final hasTitle = title is String || title is List;
  final icon = leadingIcon(theme, node.stringOr('icon'), tone, size: 16);
  final rawBullets = node.fields['bullets'];
  // Each bullet may be a plain string or a run list (for an inline accent span).
  final bullets = rawBullets is List
      ? [
          for (final b in rawBullets)
            if (b is String || b is List) b,
        ]
      : const [];
  // Nothing usable to show -> skip rather than paint a stray empty square.
  if (!hasTitle && bullets.isEmpty) return const SizedBox.shrink();
  // Accent/default sit on the theme's card surface (the figma "use case" card —
  // a subtle dark gradient when the theme sets one, else flat surface); only
  // critical tints its box. The wire names the tone; the surface is the theme's.
  final bg = tone == 'critical' ? theme.toneSurface('critical') : theme.surface;
  final grad = tone == 'critical' ? null : theme.cardGradient;
  // Flat tone color on the title (the figma card titles are solid accent, not
  // the accent gradient); run-level tones inside the title still resolve.
  final titleColor = switch (tone) {
    'accent' => theme.accent,
    'critical' => theme.danger,
    _ => theme.onSurface,
  };
  final titleStyle =
      theme.body.copyWith(fontWeight: FontWeight.w500, color: titleColor);
  final titleWidget = neoText(theme, title, titleStyle);
  return DecoratedBox(
    decoration: shapeDecoration(
      node.stringOr('shape'),
      // The figma "use case" card is the theme's large card radius (16), not the
      // medium chip radius — a callout IS a card, so it takes the card roles.
      theme.radiusLg,
      fallback: 'rounded',
      color: bg,
      gradient: grad,
    ),
    child: Padding(
      // Card insets (20h / 18v), not the tight `spaceMd` box — the figma callout
      // breathes like every other card, not like an inline chip.
      padding: theme.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            if (icon != null)
              Row(
                // Icon at the top, aligned with the title's first line (the figma
                // "start" alignment) — a wrapping title keeps the glyph up top,
                // not floated to its vertical centre.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  icon,
                  SizedBox(width: theme.spaceSm),
                  Expanded(child: titleWidget),
                ],
              )
            else
              titleWidget,
            const SizedBox(height: 4),
          ],
          // Bullets read as a list (the figma "do one of these" callout): the
          // first line is emphasized (full white — the primary fix), the rest at
          // 70% white. 2+ bullets get a leading dot in their own shade; a lone
          // supporting line stays dotless.
          for (var i = 0; i < bullets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _bullet(
                theme,
                bullets[i],
                dotted: bullets.length > 1,
                emphasized: i == 0,
              ),
            ),
        ],
      ),
    ),
  );
}

/// One callout bullet: [value] (string-or-runs) in white when [emphasized] (the
/// first, primary line), else 70% white, with a leading dot in the same shade
/// when [dotted]. Inline `tone` runs (a green "from NeoSapien") still resolve
/// through neoText on top of this base color.
Widget _bullet(NeoSduiTheme theme, Object? value,
    {required bool dotted, required bool emphasized}) {
  final color = emphasized
      ? theme.textPrimary
      : theme.textPrimary.withValues(alpha: 0.7);
  final text = neoText(theme, value, theme.caption.copyWith(color: color));
  if (!dotted) return text;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 6, right: 8),
        width: 3,
        height: 3,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Expanded(child: text),
    ],
  );
}
