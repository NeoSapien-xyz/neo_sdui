import 'package:flutter/widgets.dart';

/// Resolves the wire `shape` role to real geometry. The wire names the role
/// (`"shape":"squircle"` — the same species as `tone`/`emphasis`: an enum, never
/// a pixel), the theme owns the radius. `squircle` → a rounded superellipse (the
/// Figma squircle); anything else → a plain rounded rect. [fallback] is the
/// block's current shape, used when the wire omits `shape` — so the field is
/// purely opt-in and omitting it never changes today's look.
bool isSquircle(String? shape, String fallback) => (shape ?? fallback) == 'squircle';

/// Clips [child] to the resolved shape at [radius]. Rounded stays `ClipRRect`
/// (unchanged pixels); only squircle takes the superellipse path.
Widget clipShape(
  String? shape,
  BorderRadius radius, {
  required String fallback,
  required Widget child,
}) =>
    isSquircle(shape, fallback)
        ? ClipRSuperellipse(borderRadius: radius, child: child)
        : ClipRRect(borderRadius: radius, child: child);

/// The resolved shape as a [ShapeBorder], for surfaces clipped/painted through a
/// `ShapeBorderClipper` or `ShapeDecoration` (the card).
ShapeBorder shapeBorder(String? shape, BorderRadius radius, {required String fallback}) =>
    isSquircle(shape, fallback)
        ? RoundedSuperellipseBorder(borderRadius: radius)
        : RoundedRectangleBorder(borderRadius: radius);

/// A filled surface at the resolved shape. Rounded stays `BoxDecoration`
/// (byte-identical to before); only squircle becomes a `ShapeDecoration`, so a
/// wire that never sets `shape` regenerates no goldens.
Decoration shapeDecoration(
  String? shape,
  BorderRadius radius, {
  required String fallback,
  required Color color,
}) =>
    isSquircle(shape, fallback)
        ? ShapeDecoration(color: color, shape: RoundedSuperellipseBorder(borderRadius: radius))
        : BoxDecoration(color: color, borderRadius: radius);
