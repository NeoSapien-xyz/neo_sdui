import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Future<void> _pump(
  WidgetTester tester,
  NeoSduiTheme theme, {
  bool disableAnimations = false,
}) =>
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
                document: NeoDocument.fromJson({
                  'version': 1,
                  'blocks': [
                    {
                      'type': 'faq',
                      'items': [
                        {'question': 'Q1', 'answer': 'A1'},
                        {'question': 'Q2', 'answer': 'A2'},
                      ],
                    },
                  ],
                }),
                theme: theme,
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

AnimatedRotation _caret(WidgetTester tester) =>
    tester.widget<AnimatedRotation>(find.byType(AnimatedRotation).first);

void main() {
  testWidgets(
    'the default caret is a › that turns a quarter and tints accent',
    (tester) async {
      final theme = NeoSduiTheme.fallback();
      await _pump(tester, theme);
      await tester.pumpAndSettle();
      expect(_caret(tester).turns, 0);
      expect(find.text('›'), findsNWidgets(2));
      expect(
        tester.widget<Text>(find.text('›').first).style?.color,
        theme.textPrimary,
      );

      await tester.tap(find.text('Q1'));
      await tester.pumpAndSettle();
      expect(_caret(tester).turns, 0.25);
      expect(
        tester.widget<Text>(find.text('›').first).style?.color,
        theme.accent,
      );
    },
  );

  testWidgets('caretGlyph with openTurns rotates the custom glyph', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      faq: NeoFaqStyle(
        caretGlyph: (size, color) =>
            SizedBox(key: const Key('glyph'), width: size, height: size),
        openTurns: 0.125,
      ),
    );
    await _pump(tester, theme);
    expect(find.text('›'), findsNothing);
    expect(find.byKey(const Key('glyph')), findsNWidgets(2));
    await tester.tap(find.text('Q1'));
    await tester.pumpAndSettle();
    expect(_caret(tester).turns, 0.125);
  });

  testWidgets('itemDecoration renders each item as its own box with itemGap', (
    tester,
  ) async {
    const deco = BoxDecoration(color: Color(0xFF112233));
    final theme = NeoSduiTheme.fallback().copyWith(
      faq: const NeoFaqStyle(itemDecoration: deco, itemGap: 10),
    );
    await _pump(tester, theme);
    final boxes = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration == deco,
    );
    expect(boxes, findsNWidgets(2));
    final gap = tester.getTopLeft(boxes.at(1)).dy -
        tester.getBottomLeft(boxes.at(0)).dy;
    expect(gap, 10);
    // No hairline divider between the cards.
    expect(
      find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 1,
      ),
      findsNothing,
    );
  });

  testWidgets('reduceMotion settles the caret and answer at zero duration', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback().copyWith(reduceMotion: true);
    await _pump(tester, theme);
    await tester.tap(find.text('Q1'));
    await tester.pumpAndSettle();
    expect(_caret(tester).duration, Duration.zero);
    expect(find.text('A1'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find
                .ancestor(of: find.text('A1'), matching: find.byType(Opacity))
                .first,
          )
          .opacity,
      1,
    );
  });
}
