import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Future<void> _pump(WidgetTester tester, NeoSduiTheme theme) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: SizedBox(
              width: 400,
              height: 800,
              child: NeoSduiView(
                document: NeoDocument.fromJson({
                  'version': 1,
                  'blocks': [
                    {
                      'type': 'callout',
                      'tone': 'accent',
                      'title': 'Title',
                      'bullets': ['first', 'second'],
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

Decoration _calloutBox(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => d.decoration)
    .firstWhere(
      (d) =>
          (d is BoxDecoration && d.borderRadius != null) ||
          d is ShapeDecoration,
    );

Color? _bulletColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  testWidgets('an accent callout paints no tint under the default style', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback();
    await _pump(tester, theme);
    final box = _calloutBox(tester) as BoxDecoration;
    expect(box.color, theme.surface);
    expect(box.border, isNull);
  });

  testWidgets('toneSurfaces and border style the accent callout', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      callout: const NeoCalloutStyle(
        toneSurfaces: {'accent': Color(0x0D00F1A0)},
        border: BorderSide(color: Color(0x3300F1A0)),
      ),
    );
    await _pump(tester, theme);
    final box = _calloutBox(tester) as ShapeDecoration;
    expect(box.color, const Color(0x0D00F1A0));
    expect((box.shape as OutlinedBorder).side.color, const Color(0x3300F1A0));
  });

  testWidgets('fill, radius and padding override the card roles', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      callout: const NeoCalloutStyle(
        fill: Color(0xFF123456),
        radius: BorderRadius.all(Radius.circular(5)),
        padding: EdgeInsets.all(7),
      ),
    );
    await _pump(tester, theme);
    final box = _calloutBox(tester) as BoxDecoration;
    expect(box.color, const Color(0xFF123456));
    expect(box.borderRadius, const BorderRadius.all(Radius.circular(5)));
    expect(
      find.descendant(
        of: find.byType(DecoratedBox).first,
        matching: find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.all(7),
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('emphasizeFirstBullet false dims every bullet to 70% white', (
    tester,
  ) async {
    final base = NeoSduiTheme.fallback();
    await _pump(tester, base);
    expect(_bulletColor(tester, 'first'), base.textPrimary);
    expect(
      _bulletColor(tester, 'second'),
      base.textPrimary.withValues(alpha: 0.7),
    );

    await _pump(
      tester,
      base.copyWith(
        callout: const NeoCalloutStyle(emphasizeFirstBullet: false),
      ),
    );
    expect(
      _bulletColor(tester, 'first'),
      base.textPrimary.withValues(alpha: 0.7),
    );
  });
}
