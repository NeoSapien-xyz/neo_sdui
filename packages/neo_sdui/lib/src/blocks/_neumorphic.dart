import 'package:flutter/widgets.dart';

/// Black at ~26% — the dark half of every neumorphic inset (a rendering
/// constant, like the gradient-text idiom; the *fills* it shades are theme
/// roles).
const Color kInsetDark = Color(0x42000000);

/// One inner shadow: [color] blurred by [blur], cast from the edge that
/// [offset] points *away* from (a positive offset shades the top-left inner
/// edge — matching CSS `inset <dx> <dy>`; a negative offset shades bottom-right,
/// the "raised" light-top-left / dark-bottom-right look).
class Inset {
  const Inset(this.color, this.offset, this.blur);
  final Color color;
  final Offset offset;
  final double blur;
}

/// A filled, rounded box with painted-in inset shadows over its fill — the
/// building block for every neumorphic control (the tab groove, the pressed
/// pill, the command-card Copy button). Flutter's [BoxShadow] only casts
/// *outward*, so the inner shadows are a foreground [CustomPaint] clipped to the
/// box. Pass [gradient] for a graduated fill, else [color] fills flat; [border]
/// draws the optional hairline edge.
Widget neumorphic({
  required BorderRadius radius,
  Color? color,
  Gradient? gradient,
  Border? border,
  required List<Inset> insets,
  required Widget child,
}) =>
    DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: radius,
        border: border,
      ),
      child: CustomPaint(
        foregroundPainter: InsetShadowPainter(radius, insets),
        child: child,
      ),
    );

/// Paints [insets] as inner shadows inside the [radius] rounded rect: clip to
/// the box, then for each shadow fill everything *outside* an offset copy of the
/// box with the blurred colour, so the blur bleeds inward from one edge.
class InsetShadowPainter extends CustomPainter {
  const InsetShadowPainter(this.radius, this.insets);
  final BorderRadius radius;
  final List<Inset> insets;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    canvas.save();
    canvas.clipRRect(rrect);
    for (final s in insets) {
      if (s.color.a == 0) continue;
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur);
      final margin = s.blur * 3 + s.offset.distance + 4;
      final outer = Path()..addRect(rrect.outerRect.inflate(margin));
      final hole = Path()..addRRect(rrect.shift(s.offset));
      canvas.drawPath(Path.combine(PathOperation.difference, outer, hole), paint);
    }
    canvas.restore();
  }

  // Rebuilt with a fresh painter each build; repaint whenever that happens
  // (a static control, so this is rare — not per-frame).
  @override
  bool shouldRepaint(InsetShadowPainter old) => true;
}
