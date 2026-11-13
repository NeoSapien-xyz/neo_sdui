import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

(Offset, Offset) _ends(double deg, Size size) {
  final rect = Offset.zero & size;
  final m = NeoCssAngle(deg).transform(rect)!;
  return (
    MatrixUtils.transformPoint(m, rect.topCenter),
    MatrixUtils.transformPoint(m, rect.bottomCenter),
  );
}

void main() {
  test('180deg on a square box is plain top to bottom', () {
    final (s, e) = _ends(180, const Size(100, 100));
    expect((s - const Offset(50, 0)).distance, lessThan(0.01));
    expect((e - const Offset(50, 100)).distance, lessThan(0.01));
  });

  test('168deg on 358x76 matches the CSS gradient line', () {
    const w = 358.0, h = 76.0;
    final t = 168 * math.pi / 180;
    final len = (w * math.sin(t)).abs() + (h * math.cos(t)).abs();
    final dir = Offset(math.sin(t), -math.cos(t));
    const c = Offset(w / 2, h / 2);
    final (s, e) = _ends(168, const Size(w, h));
    expect((s - (c - dir * (len / 2))).distance, lessThan(0.5));
    expect((e - (c + dir * (len / 2))).distance, lessThan(0.5));
  });

  test('90deg is left to right on any box', () {
    for (final size in const [Size(200, 50), Size(80, 120)]) {
      final (s, e) = _ends(90, size);
      expect((s - Offset(0, size.height / 2)).distance, lessThan(0.01));
      expect((e - Offset(size.width, size.height / 2)).distance, lessThan(0.01));
    }
  });

  test('value equality', () {
    expect(const NeoCssAngle(168), const NeoCssAngle(168));
    expect(const NeoCssAngle(168).hashCode, const NeoCssAngle(168).hashCode);
    expect(const NeoCssAngle(168), isNot(const NeoCssAngle(90)));
  });

  test('an empty box gets no transform instead of a non-finite matrix', () {
    expect(const NeoCssAngle(226).transform(const Rect.fromLTWH(0, 0, 320, 0)),
        isNull);
  });
}
