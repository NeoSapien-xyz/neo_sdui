import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
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
      theme.radiusMd,
      fallback: 'rounded',
      color: bg,
      gradient: grad,
    ),
    child: Padding(
      padding: EdgeInsets.all(theme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTitle) ...[
            if (icon != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
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
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: neoText(theme, b, theme.caption),
            ),
        ],
      ),
    ),
  );
}
