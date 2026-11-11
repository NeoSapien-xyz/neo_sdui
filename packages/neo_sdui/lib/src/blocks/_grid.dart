import 'package:flutter/widgets.dart';

/// Paints the brand grid behind a featured surface (the intro hero, the
/// `emphasis:"high"` promo card) — a faint lattice of **rounded-square cells**,
/// NOT a hard cross-hatch of straight lines. Each cell is a rounded-rect
/// outline tiled every [step] px; where four cells meet, their rounded corners
/// pull away from the junction and leave a small rounded gap, so the grid reads
/// as tiles with curved edges (the figma node 4146-13612 texture). This is the
/// fix for the old painter, which drew straight lines crossing cleanly at every
/// intersection — the wrong motif.
///
/// Look only: the line color and cell pitch are theme roles
/// (`gridLine`/`gridSpacing`), never the wire. The corner rounding and the
/// hairline [stroke] are fixed properties of the motif (like a font weight),
/// scaled to [step] — the figma is ~3px round at a 20px pitch (≈15%).
///
/// Drawn as one [Path] stroked once, so the faint line keeps a single, uniform
/// alpha where adjacent cells share an edge (per-cell draws would double it).
/// Static — never repaints once laid out.
class GridPainter extends CustomPainter {
  const GridPainter({
    required this.line,
    this.step = 24,
    this.stroke = 1,
    double? radius,
  }) : radius = radius ?? step * 0.15;

  final Color line;
  final double step;
  final double stroke;

  /// Corner radius of each cell — the "curved edges". Defaults to ~15% of
  /// [step] (the figma's ~3px round at a 20px pitch).
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    if (step <= 0) return; // guard: a non-positive step is an infinite loop.
    final paint = Paint()
      ..color = line
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    final r = Radius.circular(radius);
    final path = Path();
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        path.addRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x, y, step, step), r));
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.line != line ||
      old.step != step ||
      old.stroke != stroke ||
      old.radius != radius;
}

/// A 1px horizontal dashed hairline (figma's `border-dashed` rule). Shared by the spacer and the step link row.
class DashedLinePainter extends CustomPainter {
  const DashedLinePainter(this.color);
  final Color color;
  static const double _dash = 3, _gap = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    for (double x = 0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) => old.color != color;
}
