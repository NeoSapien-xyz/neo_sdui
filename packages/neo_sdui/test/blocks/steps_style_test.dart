import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _fill = Color(0x05FFFFFF);

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> blocks,
  NeoSduiTheme theme,
) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 400,
            height: 1200,
            child: NeoSduiView(
              document: NeoDocument.fromJson({'version': 1, 'blocks': blocks}),
              theme: theme,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

NeoSduiTheme _carded({NeoStepsStyle steps = const NeoStepsStyle()}) =>
    NeoSduiTheme.fallback().copyWith(stepCardColor: _fill, steps: steps);

Map<String, Object?> _steps(List<Map<String, Object?>> items) => {
  'type': 'steps',
  'items': items,
};

void main() {
  testWidgets(
    'default style: first carded step reads "Step 0:", 12 between cards',
    (tester) async {
      await _pump(tester, [
        _steps([
          {'caption': 'One'},
          {'caption': 'Two'},
        ]),
      ], _carded());
      expect(find.text('Step 0:'), findsOneWidget);
      expect(find.text('Step 1:'), findsOneWidget);
      final first = tester.getRect(find.text('One'));
      final second = tester.getRect(find.text('Two'));
      // card 2's top minus card 1's bottom is the 12 gap; measure via the cards.
      final cards = find.byWidgetPredicate(
        (w) => w is Container && w.clipBehavior == Clip.antiAlias,
      );
      expect(cards, findsNWidgets(2));
      expect(
        tester.getTopLeft(cards.at(1)).dy -
            tester.getBottomLeft(cards.at(0)).dy,
        12,
      );
      expect(first.top < second.top, isTrue);
    },
  );

  testWidgets('cardGap replaces the 12', (tester) async {
    await _pump(tester, [
      _steps([
        {'caption': 'One'},
        {'caption': 'Two'},
      ]),
    ], _carded(steps: const NeoStepsStyle(cardGap: 20)));
    final cards = find.byWidgetPredicate(
      (w) => w is Container && w.clipBehavior == Clip.antiAlias,
    );
    expect(
      tester.getTopLeft(cards.at(1)).dy - tester.getBottomLeft(cards.at(0)).dy,
      20,
    );
  });

  testWidgets('labelNumberOffset 0 and empty suffix give "Step 1"', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        _steps([
          {'caption': 'One'},
        ]),
      ],
      _carded(
        steps: const NeoStepsStyle(labelNumberOffset: 0, labelSuffix: ''),
      ),
    );
    expect(find.text('Step 1'), findsOneWidget);
  });

  testWidgets('labelStyle, instructionStyle and labelGap come from the theme', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        _steps([
          {'caption': 'One'},
        ]),
      ],
      _carded(
        steps: const NeoStepsStyle(
          labelStyle: TextStyle(fontSize: 31),
          instructionStyle: TextStyle(fontSize: 33),
          labelGap: 9,
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('Step 0:')).style!.fontSize, 31);
    expect(tester.widget<Text>(find.text('One')).style!.fontSize, 33);
    expect(
      tester.getTopLeft(find.text('One')).dy -
          tester.getBottomLeft(find.text('Step 0:')).dy,
      9,
    );
  });

  testWidgets('autoLinkUrls false keeps an echoed command plain', (tester) async {
    await _pump(tester, [
      _steps([
        {'caption': 'Run it', 'code': 'npm install neo'},
      ]),
    ], _carded(steps: const NeoStepsStyle(autoLinkUrls: false)));
    final rich = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((r) => r.text.toPlainText().contains('npm install neo'));
    var underlined = false;
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.style?.decoration == TextDecoration.underline) {
        underlined = true;
      }
      return true;
    });
    expect(underlined, isFalse);
  });

  testWidgets('autoLinkUrls false leaves a bare domain plain', (tester) async {
    Future<List<InlineSpan>> spansFor(bool auto) async {
      await _pump(tester, [
        _steps([
          {'caption': 'Open claude.ai now'},
        ]),
      ], _carded(steps: NeoStepsStyle(autoLinkUrls: auto)));
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((r) => r.text.toPlainText().contains('claude.ai'));
      final out = <InlineSpan>[];
      rich.text.visitChildren((s) {
        out.add(s);
        return true;
      });
      return out;
    }

    final on = await spansFor(true);
    expect(
      on.any((s) => s is TextSpan && s.recognizer is TapGestureRecognizer),
      isTrue,
    );
    final off = await spansFor(false);
    expect(
      off.any(
        (s) =>
            s is TextSpan &&
            (s.recognizer != null ||
                s.style?.decoration == TextDecoration.underline),
      ),
      isFalse,
    );
  });

  testWidgets('steps.cardShadow overrides the step card only', (tester) async {
    const stepShadow = [BoxShadow(color: Color(0xFFFF0000), blurRadius: 7)];
    const themeShadow = [BoxShadow(color: Color(0xFF00FF00), blurRadius: 3)];
    final theme = _carded(
      steps: const NeoStepsStyle(cardShadow: stepShadow),
    ).copyWith(cardShadow: themeShadow);
    await _pump(tester, [
      _steps([
        {'caption': 'One'},
      ]),
      {'type': 'card', 'title': 'Picker'},
    ], theme);
    final shadows = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.boxShadow)
        .whereType<List<BoxShadow>>();
    expect(shadows.any((s) => s.first.color == stepShadow.first.color), isTrue);
    final cardShapes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<ShapeDecoration>()
        .expand((d) => d.shadows ?? const <BoxShadow>[]);
    expect(cardShapes.any((s) => s.color == themeShadow.first.color), isTrue);
    expect(cardShapes.any((s) => s.color == stepShadow.first.color), isFalse);
  });

  testWidgets('imageBackdrop paints behind the image while the shimmer shows', (
    tester,
  ) async {
    const backdrop = Color(0xFF123456);
    await _pump(tester, [
      _steps([
        {'caption': 'One', 'image': 'http://example.invalid/a.png'},
      ]),
    ], _carded(steps: const NeoStepsStyle(imageBackdrop: backdrop)));
    expect(find.byKey(const Key('media-shimmer')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const Key('media-shimmer')),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == backdrop,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'chip strip reads chipGap, chipBorder, badgeStyle, chipLabelStyle',
    (tester) async {
      const border = Color(0xFF0000FF);
      final theme = NeoSduiTheme.fallback().copyWith(
        stepCardColor: _fill,
        steps: const NeoStepsStyle(
          chipGap: 30,
          chipBorder: border,
          badgeStyle: TextStyle(fontSize: 17),
          chipLabelStyle: TextStyle(fontSize: 19),
        ),
      );
      await _pump(tester, [
        {
          'type': 'steps',
          'layout': 'row',
          'items': [
            {'caption': 'A'},
            {'caption': 'B'},
          ],
        },
      ], theme);
      expect(tester.widget<Text>(find.text('1')).style!.fontSize, 17);
      expect(tester.widget<Text>(find.text('A')).style!.fontSize, 19);
      final boxes = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border != null);
      expect(boxes.length, 2);
      expect(boxes.first.border!.top.color, border);
      final cells = find.byType(Expanded);
      expect(
        tester.getTopLeft(cells.at(1)).dx - tester.getTopRight(cells.at(0)).dx,
        30,
      );
    },
  );

  testWidgets('a carded step that throws is still isolated with styles set', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        _steps([
          {'caption': 'Good step'},
          {
            'caption': 'Boom',
            'blocks': [
              {42: 'non-string key throws in Map<String,Object?>.from'},
            ],
          },
        ]),
      ],
      _carded(
        steps: const NeoStepsStyle(
          cardGap: 5,
          labelStyle: TextStyle(fontSize: 14),
          imageBackdrop: Color(0xFF000000),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('step-error')), findsOneWidget);
    expect(find.text('Good step'), findsOneWidget);
  });
}
