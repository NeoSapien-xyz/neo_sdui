import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

final _actions = <NeoAction>[];

Future<void> _pump(WidgetTester tester, Object? link) async {
  _actions.clear();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: NeoSduiView(
          document: NeoDocument.fromJson({
            'version': 1,
            'blocks': [
              {
                'type': 'steps',
                'items': [
                  {
                    'caption': [
                      'Download it from ',
                      {'text': 'claude.ai/download', 'link': link},
                    ],
                  },
                ],
              },
            ],
          }),
          theme: NeoSduiTheme.fallback(),
          onAction: (_, a) => _actions.add(a),
        ),
      ),
    ),
  );
}

TextSpan _span(WidgetTester t, String text) {
  final rich = t.widget<RichText>(find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(text)));
  late TextSpan hit;
  rich.text.visitChildren((s) {
    if (s is TextSpan && s.text == text) hit = s;
    return true;
  });
  return hit;
}

void main() {
  testWidgets('an https run link is underlined and opens the url', (t) async {
    await _pump(t, 'https://claude.ai/download');
    final span = _span(t, 'claude.ai/download');
    expect(span.style!.decoration, TextDecoration.underline);
    await t.pumpAndSettle(); // let the entrance fade finish
    await t.tapOnText(find.textRange.ofSubstring('claude.ai/download'));
    expect(_actions.single, isA<ExternalUrl>());
    expect((_actions.single as ExternalUrl).url.toString(),
        'https://claude.ai/download');
  });

  testWidgets('the rest of the caption stays plain', (t) async {
    await _pump(t, 'https://claude.ai/download');
    expect(_span(t, 'Download it from ').recognizer, isNull);
  });

  for (final bad in ['javascript:alert(1)', 'claude.ai/download', 42]) {
    testWidgets('a non-http run link ($bad) renders plain', (t) async {
      await _pump(t, bad);
      final span = _span(t, 'claude.ai/download');
      expect(span.recognizer, isNull);
      expect(span.style?.decoration, isNot(TextDecoration.underline));
    });
  }

  test('the vocabulary gate warns on a non-http run link', () {
    final issues = validateWireVocabulary({
      'version': 1,
      'blocks': [
        {
          'type': 'steps',
          'items': [
            {
              'caption': [
                {'text': 'x', 'link': 'ftp://a.b'},
                {'text': 'y', 'link': 'https://a.b'},
              ],
            },
          ],
        },
      ],
    });
    expect(issues, hasLength(1));
    expect(issues.single.path, 'blocks[0].items[0].caption[0].link');
    expect(issues.single.isBlocking, isFalse);
  });
}
