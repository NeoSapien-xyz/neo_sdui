import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';

/// A block's leading role-icon, or null when the wire names none / nothing
/// resolves it (draw nothing — graceful, like a null accentGradient). The wire
/// carries only the icon *name* (e.g. `"sparkle"`); the glyph, size and tone
/// color are the theme's (KTD9). `tone` tints it via [NeoSduiTheme.toneColor] —
/// accent → the accent green, critical → danger, else onSurface. Resolution is:
/// a theme `icons.<name>` glyph first (an app's own AppIcons override wins),
/// then a package-drawn glyph ([kDrawnIcons], e.g. the brand `sparkle`), else
/// null.
Widget? leadingIcon(
  NeoSduiTheme theme,
  String? name,
  String? tone, {
  double size = 16,
}) {
  final color = theme.toneColor(tone);
  final data = theme.iconFor(name);
  if (data != null) return Icon(data, size: size, color: color);
  if (name != null && kDrawnIcons.contains(name)) {
    return _drawnIcon(name, size, color);
  }
  return null;
}

/// A package-drawn icon glyph, for the [kDrawnIcons] names the theme doesn't map
/// to a font [IconData]. One `switch` so [kDrawnIcons] stays the single source
/// of truth the lint reads.
Widget _drawnIcon(String name, double size, Color color) => switch (name) {
      'sparkle' => NeoSparkleIcon(size: size, color: color),
      _ => const SizedBox.shrink(),
    };

/// The NeoSapien two-pointed sparkle star (figma "Bold / Weather / Stars"): a
/// large 4-point star with a smaller one at its lower-right, both pinched
/// (concave sides). Drawn rather than mapped to a Material glyph because
/// `Icons.auto_awesome` is a visibly different 3-sparkle mark. Filled in the
/// resolved tone [color]; the size is the theme's (the leading-icon size role).
class NeoSparkleIcon extends StatelessWidget {
  const NeoSparkleIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('icon-sparkle'),
        size: Size.square(size),
        painter: _SparklePainter(color),
      );
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // The figma glyph is authored in a 16-unit box; scale to the drawn size.
    final s = size.width / 16;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final path = Path()
      ..addPath(_star(const Offset(5.67, 5.67), 4.5), Offset.zero)
      ..addPath(_star(const Offset(11.67, 11.67), 3.0), Offset.zero);
    canvas.drawPath(
      path.transform(Matrix4.diagonal3Values(s, s, 1).storage),
      paint,
    );
  }

  /// One 4-point sparkle centered at [c] with outer radius [r]: sharp N/E/S/W
  /// points joined by concave (inward-bowing) sides — the control point sits
  /// well inside the chord to pinch each side toward the center.
  Path _star(Offset c, double r) {
    final k = r * 0.36; // control inset: smaller -> deeper pinch.
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}
