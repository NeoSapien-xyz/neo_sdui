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
      'export' => NeoExportIcon(size: size, color: color),
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

/// The figma "Bold / Arrows Action / Export" glyph (a bold up-arrow rising out
/// of an open-top tray — the use-case "Export data" row). Drawn rather than
/// mapped to a Material glyph because `Icons.ios_share` is a visibly different
/// mark (a rounded-square share sheet) and read as mis-sized. Filled in the
/// resolved tone [color]; the size is the theme's (the leading-icon size role).
class NeoExportIcon extends StatelessWidget {
  const NeoExportIcon({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        key: const Key('icon-export'),
        size: Size.square(size),
        painter: _ExportPainter(color),
      );
}

/// The two filled paths of the figma export vector, transcribed verbatim from
/// its SVG (viewBox 9.33×9.77). The vector sits inset inside a 14-unit icon box
/// (figma inset 18.23% left / 15.10% top); authored here in that 14-box and
/// scaled to the drawn size, so it reproduces the glyph's own padding rather
/// than filling the box edge-to-edge — matching how the figma renders it.
class _ExportPainter extends CustomPainter {
  const _ExportPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final path = Path()
      // The up-arrow.
      ..moveTo(2.60731, 2.49686)
      ..cubicTo(2.77816, 2.66771, 3.05517, 2.66771, 3.22603, 2.49686)
      ..lineTo(4.22917, 1.49372)
      ..lineTo(4.22917, 6.27083)
      ..cubicTo(4.22917, 6.51246, 4.42504, 6.70833, 4.66667, 6.70833)
      ..cubicTo(4.90829, 6.70833, 5.10417, 6.51246, 5.10417, 6.27083)
      ..lineTo(5.10417, 1.49372)
      ..lineTo(6.10731, 2.49686)
      ..cubicTo(6.27816, 2.66771, 6.55517, 2.66771, 6.72603, 2.49686)
      ..cubicTo(6.89688, 2.326, 6.89688, 2.049, 6.72603, 1.87814)
      ..lineTo(4.97603, 0.128141)
      ..cubicTo(4.80517, -0.0427136, 4.52816, -0.0427136, 4.35731, 0.128141)
      ..lineTo(2.60731, 1.87814)
      ..cubicTo(2.43645, 2.049, 2.43645, 2.326, 2.60731, 2.49686)
      ..close()
      // The open-top tray below it.
      ..moveTo(4.66667, 9.77083)
      ..cubicTo(7.244, 9.77083, 9.33333, 7.6815, 9.33333, 5.10417)
      ..lineTo(7.14583, 5.10417)
      ..cubicTo(6.59586, 5.10417, 6.32088, 5.10417, 6.15002, 5.27502)
      ..cubicTo(5.97917, 5.44588, 5.97917, 5.72086, 5.97917, 6.27083)
      ..cubicTo(5.97917, 6.99571, 5.39154, 7.58333, 4.66667, 7.58333)
      ..cubicTo(3.94179, 7.58333, 3.35417, 6.99571, 3.35417, 6.27083)
      ..cubicTo(3.35417, 5.72086, 3.35417, 5.44588, 3.18331, 5.27502)
      ..cubicTo(3.01246, 5.10417, 2.73747, 5.10417, 2.1875, 5.10417)
      ..lineTo(0, 5.10417)
      ..cubicTo(0, 7.6815, 2.08934, 9.77083, 4.66667, 9.77083)
      ..close();
    final s = size.width / 14.0;
    canvas.save();
    canvas.scale(s);
    canvas.translate(2.552, 2.115); // the vector's inset within the 14-unit box
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ExportPainter old) => old.color != color;
}
