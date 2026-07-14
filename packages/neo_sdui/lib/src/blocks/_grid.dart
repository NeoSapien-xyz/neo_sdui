import 'package:flutter/widgets.dart';

/// Paints a faint square grid — thin lines every [step] px — behind a featured
/// container (the NeoSapien branded surface, e.g. a `group` with
/// `emphasis:"high"`). Look only: the line color and spacing come from the theme
/// (`gridLine`/`gridSpacing`), never the wire. Static, so it never repaints once
/// laid out.
class GridPainter extends CustomPainter {
  const GridPainter({required this.line, this.step = 24, this.stroke = 1});
  final Color line;
  final double step;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (step <= 0) return; // guard: a non-positive step is an infinite loop.
    final paint = Paint()
      ..color = line
      ..strokeWidth = stroke;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.line != line || old.step != step || old.stroke != stroke;
}
