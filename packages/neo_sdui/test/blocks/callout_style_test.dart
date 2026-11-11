import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Future<void> _pump(WidgetTester tester, NeoSduiTheme theme,
        {String tone = 'accent'}) =>
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
                      'tone': tone,
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

  testWidgets('a tone surface wins over the generic fill', (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      callout: const NeoCalloutStyle(
        fill: Color(0x05FFFFFF),
        toneSurfaces: {'accent': Color(0x0D00F1A0)},
      ),
    );
    await _pump(tester, theme);
    expect(
      (_calloutBox(tester) as BoxDecoration).color,
      const Color(0x0D00F1A0),
    );
    // A tone with no entry still takes the generic fill.
    await _pump(tester, theme, tone: 'other');
    expect(
      (_calloutBox(tester) as BoxDecoration).color,
      const Color(0x05FFFFFF),
    );
  });

  testWidgets('toneBorders beat the generic border, per tone', (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      callout: const NeoCalloutStyle(
        border: BorderSide(color: Color(0x14FFFFFF)),
        toneBorders: {'warning': BorderSide(color: Color(0x40FFC454))},
      ),
    );
    await _pump(tester, theme, tone: 'warning');
    final warn = _calloutBox(tester) as ShapeDecoration;
    expect((warn.shape as OutlinedBorder).side.color, const Color(0x40FFC454));
    await _pump(tester, theme);
    final plain = _calloutBox(tester) as ShapeDecoration;
    expect((plain.shape as OutlinedBorder).side.color, const Color(0x14FFFFFF));
  });

  testWidgets('a warning callout titles in the warning colour', (tester) async {
    final theme = NeoSduiTheme.fallback();
    await _pump(tester, theme, tone: 'warning');
    expect(tester.widget<Text>(find.text('Title')).style?.color, theme.warning);
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
