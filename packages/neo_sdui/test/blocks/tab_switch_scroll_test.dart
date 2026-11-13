import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

List<Map<String, Object?>> _tab(String name, int n) => [
      {'type': 'header', 'title': 'Quick setup $name', 'subtitle': 'sub $name'},
      for (var i = 0; i < n; i++) {'type': 'text', 'body': '$name step $i'},
    ];

NeoDocument _doc({required int desk}) => NeoDocument.fromJson({
      'version': 1,
      'blocks': [
        {
          'type': 'tabs',
          'header': [
            {'type': 'text', 'body': 'shared header'},
          ],
          'tabs': [
            {'label': 'Web', 'blocks': _tab('web', 60)},
            {'label': 'Desktop', 'blocks': _tab('desk', desk)},
          ],
        },
      ],
    });

/// Pumps frame by frame through a top-level tab swap and returns
/// `(pixels, maxScrollExtent)` for each frame.
Future<List<(double, double)>> _swap(WidgetTester tester, int desk) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 400,
            height: 800,
            // Motion on (the default): the swap is the SwapFade fade + rise.
            child: NeoSduiView(
              document: _doc(desk: desk),
              theme: NeoSduiTheme.fallback(),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final pos =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  pos.jumpTo(300);
  await tester.pump();
  await tester.tap(find.text('Desktop'));
  final frames = <(double, double)>[];
  for (var f = 0; f < 30; f++) {
    await tester.pump(const Duration(milliseconds: 16));
    frames.add((pos.pixels, pos.maxScrollExtent));
  }
  return frames;
}

void main() {
  testWidgets('a same-height tab swap keeps the offset and extent every frame',
      (tester) async {
    final frames = await _swap(tester, 60);
    expect(frames.map((f) => f.$1).toSet(), {300.0});
    expect(frames.map((f) => f.$2).toSet().length, 1,
        reason: 'the content extent must not collapse then regrow');
  });

  testWidgets('a shorter tab clamps the offset once, on the swap frame only',
      (tester) async {
    final frames = await _swap(tester, 8);
    final clamped = frames.first.$1;
    expect(clamped, lessThan(300), reason: 'old tab is gone, offset clamps');
    // No later frame moves again: no regrow, no second settle.
    expect(frames.every((f) => f == frames.first), isTrue, reason: '$frames');
  });
}
