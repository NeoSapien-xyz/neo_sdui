import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Makes a [LinearGradient] follow a CSS `linear-gradient(<deg>, ...)` angle.
///
/// Pair it with `begin: Alignment.topCenter, end: Alignment.bottomCenter`.
/// The transform maps that axis onto the CSS gradient line for the paint
/// bounds: 0deg points up, 90deg right, clockwise, with line length
/// `|w*sin| + |h*cos|` through the box centre. A fixed [Alignment] pair
/// is box-relative and so draws a different angle on a wide short box.
class NeoCssAngle extends GradientTransform {
  const NeoCssAngle(this.degrees);

  final double degrees;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final t = degrees * math.pi / 180;
    final length =
        (bounds.width * math.sin(t)).abs() + (bounds.height * math.cos(t)).abs();
    final c = bounds.center;
    // Stretch the vertical axis to the CSS line length, then turn it from
    // pointing down (180deg) to the requested angle.
    return Matrix4.translationValues(c.dx, c.dy, 0)
      ..rotateZ(t - math.pi)
      ..scaleByDouble(1, length / bounds.height, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  bool operator ==(Object other) =>
      other is NeoCssAngle && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;
}
