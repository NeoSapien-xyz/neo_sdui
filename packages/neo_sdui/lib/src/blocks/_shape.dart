import 'package:flutter/widgets.dart';

/// Resolves the wire `shape` role to real geometry. The wire names the role
/// (`"shape":"squircle"` — the same species as `tone`/`emphasis`: an enum, never
/// a pixel), the theme owns the radius. Recognized roles are `squircle` (a
/// rounded superellipse — the Figma squircle) and `rounded` (a plain rounded
/// rect); anything else — omitted, empty, or an unrecognized token — resolves to
/// [fallback], the block's current shape. So the field is purely opt-in: a typo
/// degrades to the block's default rather than silently flipping its look.
bool _isSquircle(String? shape, {required String fallback}) {
  final resolved = (shape == 'squircle' || shape == 'rounded') ? shape : fallback;
  return resolved == 'squircle';
}

/// Clips [child] to the resolved shape at [radius]. Rounded stays `ClipRRect`
/// (unchanged pixels); only squircle takes the superellipse path.
Widget clipShape(
  String? shape,
  BorderRadius radius, {
  required String fallback,
  required Widget child,
}) =>
    _isSquircle(shape, fallback: fallback)
        ? ClipRSuperellipse(borderRadius: radius, child: child)
        : ClipRRect(borderRadius: radius, child: child);

/// The resolved shape as a [ShapeBorder], for surfaces clipped/painted through a
/// `ShapeBorderClipper` or `ShapeDecoration` (the card).
ShapeBorder shapeBorder(String? shape, BorderRadius radius, {required String fallback}) =>
    _isSquircle(shape, fallback: fallback)
        ? RoundedSuperellipseBorder(borderRadius: radius)
        : RoundedRectangleBorder(borderRadius: radius);

/// A filled surface at the resolved shape. An optional [gradient] fills instead
/// of [color] when set (the featured-group case); a null gradient keeps the flat
/// [color], byte-identical to before. Rounded stays `BoxDecoration`; only
/// squircle becomes a `ShapeDecoration`, so a wire that never sets `shape`
/// regenerates no goldens.
Decoration shapeDecoration(
  String? shape,
  BorderRadius radius, {
  required String fallback,
  required Color color,
  Gradient? gradient,
}) =>
    _isSquircle(shape, fallback: fallback)
        ? ShapeDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            shape: shapeBorder(shape, radius, fallback: fallback),
          )
        : BoxDecoration(
            color: gradient == null ? color : null,
            gradient: gradient,
            borderRadius: radius,
          );
