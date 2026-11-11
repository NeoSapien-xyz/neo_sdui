import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_motion.dart';
import '_neumorphic.dart';
import '_shape.dart';

/// The featured-CTA neumorphic emboss — the neo app's green button
/// (FigmaLinearGradientButton / figma node 4146:14473): a light top-left + dark
/// bottom-right inset over the ctaGradient, for the pressed, embossed look. A
/// rendering idiom like the gradient-text srcIn (the *fill* is the theme's
/// ctaGradient; only the emboss geometry is baked here).
const List<Inset> _ctaEmboss = [
  Inset(Color(0x33CECECE), Offset(6, 6), 10), // inset 6 6 10 rgba(206,206,206,.2)
  Inset(Color(0x33000000), Offset(-6, -6), 20), // inset -6 -6 20 rgba(0,0,0,.2)
];

/// cta: tappable pill. Fill/text derived from `emphasis` (high/normal/low);
/// corner from the optional `shape` role (default rounded). `align:"center"`
/// makes it a content-hugging pill centered in its column (the troubleshooting
/// "Contact Support" button) instead of stretching to the column width. A
/// *featured* cta (`emphasis:"high"` + a theme `ctaGradient`) takes the neo
/// green button's neumorphic emboss + soft drop; every other cta stays flat.
Widget buildCta(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final action = node.stringOr('action', '')!;
  final emphasis = node.stringOr('emphasis');
  final centered = node.stringOr('align') == 'center';
  final featured = emphasis == 'high' && theme.ctaGradient != null;
  // A label is a label: `featured` changes the *surface* (gradient + emboss),
  // never the type scale — that stays the theme's `body` role for every cta.
  final label = theme.emphasize(theme.body).copyWith(color: theme.onFill(emphasis));
  final content = Padding(
    padding: EdgeInsets.symmetric(vertical: 14, horizontal: theme.spaceLg),
    child: Center(child: Text(node.stringOr('label', '')!, style: label)),
  );
  final Widget box = featured
      ? neumorphic(
          radius: theme.radiusSm,
          gradient: theme.ctaGradient,
          insets: _ctaEmboss,
          child: content,
        )
      : DecoratedBox(
          decoration: shapeDecoration(
            node.stringOr('shape'),
            theme.radiusMd,
            fallback: 'rounded',
            color: theme.fill(emphasis),
          ),
          child: content,
        );
  // A featured cta lifts on a soft outer drop (figma 0 4 10 rgba(0,0,0,0.2)).
  final surface = featured
      ? DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: theme.radiusSm,
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 10),
            ],
          ),
          child: box,
        )
      : box;
  final pill = PressScale(
    onTap: () => scope.dispatch(context, NeoAction.parse(action)),
    child: surface,
  );
  // Centered: hug the label and sit centre-stage. Default: a Row-less box that
  // stretches to the column width (unchanged).
  return centered
      ? Align(
          alignment: Alignment.center,
          child: IntrinsicWidth(child: pill),
        )
      : pill;
}
