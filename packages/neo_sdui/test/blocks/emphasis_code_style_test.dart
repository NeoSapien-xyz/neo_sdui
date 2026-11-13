import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui/src/blocks/_motion.dart' show TurningCaret;

Future<void> _pump(
    WidgetTester tester, List<Map<String, Object?>> blocks, NeoSduiTheme theme) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 300,
            height: 900,
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

// A style whose family names the w500 face, as google_fonts does
// ("WorkSans_500"): copyWith(fontWeight) alone never changes the family.
const _strong = TextStyle(
    fontFamily: 'WorkSans_500',
    fontFamilyFallback: ['Work Sans'],
    fontWeight: FontWeight.w500);

TextStyle _runStyle(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains(text)));
  TextStyle? found;
  rich.text.visitChildren((s) {
    if (s is TextSpan && s.text == text) found = s.style;
    return true;
  });
  return found!;
}

void main() {
  final base = NeoSduiTheme.fallback()
      .copyWith(accents: const {'strong': NeoAccent(Color(0xFFFFFFFF))});

  testWidgets('a strong run takes the theme strong role family, not just a weight',
      (tester) async {
    final t = base.copyWith(strong: _strong);
    await _pump(tester, [
      {'type': 'text', 'body': ['Tap ', {'text': 'Customize', 'tone': 'strong'}, ' now']}
    ], t);
    final s = _runStyle(tester, 'Customize');
    expect(s.fontWeight, FontWeight.w500);
    expect(s.fontFamily, 'WorkSans_500');
  });

  testWidgets('no strong role keeps the weight-only copyWith', (tester) async {
    await _pump(tester, [
      {'type': 'text', 'body': ['Tap ', {'text': 'Customize', 'tone': 'strong'}, ' now']}
    ], base);
    final s = _runStyle(tester, 'Customize');
    expect(s.fontWeight, FontWeight.w500);
    expect(s.fontFamily, base.body.fontFamily);
  });

  testWidgets('code defaults: a themed-surface single box with a Copy text chip',
      (tester) async {
    await _pump(tester, [
      {'type': 'code', 'content': 'https://api.neosapien.xyz/mcp'}
    ], base);
    expect(find.byKey(const Key('code-copy')), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('code style: fill, radius, single line, copy glyph instead of text',
      (tester) async {
    const fill = Color(0xFF0B0C0C);
    final t = base.copyWith(
      code: NeoCodeStyle(
        fill: fill,
        radius: BorderRadius.circular(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
        wrap: false,
        copyGlyph: (size, c) => SizedBox(key: const Key('glyph'), width: size, height: size),
      ),
    );
    await _pump(tester, [
      {'type': 'code', 'content': 'https://api.neosapien.xyz/mcp/very/long/path/that/would/wrap/on/a/narrow/box'}
    ], t);
    expect(find.text('Copy'), findsNothing);
    expect(find.byKey(const Key('glyph')), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find
        .descendant(of: find.byType(NeoSduiView), matching: find.byType(DecoratedBox))
        .first);
    final d = box.decoration as BoxDecoration;
    expect(d.color, fill);
    expect(d.borderRadius, BorderRadius.circular(12));
    // wraps instead of scrolling: the whole string is laid out and its right
    // edge stays left of the copy button (44 = 28 button + 2 * 8 inset).
    final text = find.textContaining('https://api');
    expect(tester.getSize(text).height, greaterThan(25));
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.getTopRight(text).dx,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('glyph'))).dx));
  });

  testWidgets('steps blocksOutsideCard lifts an item block out of its card',
      (tester) async {
    Future<void> go(bool outside) => _pump(tester, [
          {
            'type': 'steps',
            'items': [
              {
                'caption': 'Paste',
                'blocks': [
                  {'type': 'code', 'content': 'abc'}
                ]
              },
            ]
          }
        ], base.copyWith(stepCardColor: const Color(0x05FFFFFF), steps: NeoStepsStyle(blocksOutsideCard: outside)));
    await go(false);
    final card = find.byWidgetPredicate(
        (w) => w is Container && w.clipBehavior == Clip.antiAlias);
    expect(
        find.descendant(of: card, matching: find.text('abc')), findsOneWidget);
    await go(true);
    expect(find.descendant(of: card, matching: find.text('abc')), findsNothing);
    expect(find.text('abc'), findsOneWidget);
  });

  testWidgets('neutral callout title + icon take neutralTitleColor', (tester) async {
    const green = Color(0xFF00F1A0);
    await _pump(tester, [
      {'type': 'callout', 'icon': 'sparkle', 'title': 'Not getting results?'}
    ], base.copyWith(callout: const NeoCalloutStyle(neutralTitleColor: green)));
    final t = tester.widget<RichText>(find
        .descendant(of: find.byType(NeoSduiView), matching: find.byType(RichText))
        .first);
    expect(t.text.style?.color ?? (t.text as TextSpan).children?.first.style?.color, green);
  });

  testWidgets('faq questionStyle sets the question line height', (tester) async {
    await _pump(tester, [
      {'type': 'faq', 'items': [{'question': 'Q one', 'answer': 'A'}]}
    ], base.copyWith(faq: NeoFaqStyle(questionStyle: base.body.copyWith(fontSize: 14, height: 2))));
    expect(tester.getSize(find.text('Q one')).height, 28);
  });

  testWidgets('a centered header centers a wrapped title line by line',
      (tester) async {
    await _pump(tester, [
      {'type': 'header', 'title': 'Here is what it does for you and more', 'align': 'center'}
    ], base);
    final text = find.text('Here is what it does for you and more');
    expect(DefaultTextStyle.of(tester.element(text)).textAlign, TextAlign.center);
  });

  testWidgets('faq caretBox sets the row height', (tester) async {
    Future<double> h(NeoFaqStyle f) async {
      await _pump(tester, [
        {'type': 'faq', 'items': [{'question': 'Q', 'answer': 'A'}]}
      ], base.copyWith(faq: f));
      return tester.getSize(find.byType(TurningCaret)).height;
    }
    expect(await h(const NeoFaqStyle()), 24);
    expect(await h(const NeoFaqStyle(caretBox: 18, caretSize: 18)), 18);
  });

  testWidgets('a toneless callout takes neutralBody as is; a toned one does not',
      (tester) async {
    const own = TextStyle(fontSize: 12, color: Color(0xFF868686));
    final t = base.copyWith(callout: const NeoCalloutStyle(neutralBody: own));
    await _pump(tester, [
      {'type': 'callout', 'title': 'T', 'bullets': ['plain']},
      {'type': 'callout', 'tone': 'accent', 'title': 'T2', 'bullets': ['toned']},
    ], t);
    expect(tester.widget<Text>(find.text('plain')).style, own);
    expect(tester.widget<Text>(find.text('toned')).style!.color, isNot(own.color));
  });
}
