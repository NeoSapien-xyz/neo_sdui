import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

NeoDocument _doc(int blocks) => NeoDocument.fromJson({
      'version': 1,
      'blocks': [
        for (var i = 0; i < blocks; i++) {'type': 'text', 'body': 'block $i'},
      ],
    });

Future<void> _pump(WidgetTester tester, NeoDocument doc,
        {NeoSduiTheme? theme, bool disableAnimations = false}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: NeoSduiView(
                document: doc,
                theme: theme ?? NeoSduiTheme.fallback(),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

/// The painted opacity of a block, or null when nothing wraps it.
double? _opacityOf(WidgetTester tester, String text) {
  final finder = find.ancestor(
    of: find.text(text),
    matching: find.byType(Opacity),
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Opacity>(finder.first).opacity;
}

void main() {
  testWidgets('a block starts transparent and settles opaque', (tester) async {
    await _pump(tester, _doc(1));
    expect(_opacityOf(tester, 'block 0'), 0);
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, 'block 0'), 1);
  });

  testWidgets('blocks stagger — a later block is still behind an earlier one',
      (tester) async {
    await _pump(tester, _doc(3));
    // Past the first block's delay (0ms) but not the third's (95ms): the first
    // is under way while the third has not started.
    await tester.pump(const Duration(milliseconds: 60));
    final first = _opacityOf(tester, 'block 0')!;
    final third = _opacityOf(tester, 'block 2')!;
    expect(first, greaterThan(0));
    expect(third, lessThan(first));
  });

  testWidgets('every block lands opaque, including past the delay table',
      (tester) async {
    await _pump(tester, _doc(9));
    await tester.pumpAndSettle();
    for (var i = 0; i < 9; i++) {
      final opacity = _opacityOf(tester, 'block $i');
      // Past the table a block is never wrapped at all — which reads the same
      // as a settled one, and is the point.
      expect(opacity ?? 1, 1, reason: 'block $i');
    }
  });

  testWidgets('reduceMotion renders blocks outright — no fade to wait on',
      (tester) async {
    await _pump(tester, _doc(3),
        theme: NeoSduiTheme.fallback().copyWith(reduceMotion: true));
    // No pump: with motion off the blocks are simply there, at full strength.
    for (var i = 0; i < 3; i++) {
      expect(_opacityOf(tester, 'block $i'), isNull);
      expect(find.text('block $i'), findsOneWidget);
    }
  });

  testWidgets("the platform's reduce-motion switch kills the entrance too",
      (tester) async {
    // The theme says animate; the platform says don't. The platform wins.
    await _pump(tester, _doc(3), disableAnimations: true);
    for (var i = 0; i < 3; i++) {
      expect(_opacityOf(tester, 'block $i'), isNull);
      expect(find.text('block $i'), findsOneWidget);
    }
  });

  testWidgets('an untouched theme survives rebuild by identity', (tester) async {
    // The scope notifies on a new theme instance, so folding the platform switch
    // in must not mint a fresh theme when it has nothing to change.
    final theme = NeoSduiTheme.fallback();
    await _pump(tester, _doc(1), theme: theme);
    final scope = NeoSduiScope.of(
      tester.element(find.text('block 0')),
    );
    expect(identical(scope.theme, theme), isTrue);
  });

  testWidgets('a zeroed entranceDuration is a kill switch, not a divide by zero',
      (tester) async {
    await _pump(tester, _doc(3),
        theme: NeoSduiTheme.fallback()
            .copyWith(entranceDuration: Duration.zero));
    expect(_opacityOf(tester, 'block 0'), isNull);
    expect(find.text('block 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
