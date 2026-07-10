import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

final _theme = NeoSduiTheme.fallback();

Future<void> _pump(
  WidgetTester tester,
  Map<String, Object?> block, {
  NeoActionHandler? onAction,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 400,
            height: 800,
            child: NeoSduiView(
              document: NeoDocument.fromJson({'version': 1, 'blocks': [block]}),
              theme: _theme,
              onAction: onAction ?? (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('card renders title, subtitle and taps its action', (tester) async {
    NeoAction? got;
    await _pump(
      tester,
      {
        'type': 'card',
        'title': 'ChatGPT',
        'subtitle': 'Web / Desktop App',
        'action': 'route:chatgpt',
      },
      onAction: (_, a) => got = a,
    );
    expect(find.text('ChatGPT'), findsOneWidget);
    expect(find.text('Web / Desktop App'), findsOneWidget);
    await tester.tap(find.text('ChatGPT'));
    expect(got, isA<RouteAction>());
    expect((got as RouteAction).name, 'chatgpt');
  });

  testWidgets('card without subtitle renders just the title', (tester) async {
    await _pump(tester, {'type': 'card', 'title': 'Only'});
    expect(find.text('Only'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('steps numbers items and isolates a malformed one', (tester) async {
    await _pump(tester, {
      'type': 'steps',
      'items': [
        {'caption': 'Pick your AI'},
        {'caption': 42}, // malformed -> placeholder, numbering intact
        {'caption': 'Ask it anything'},
      ],
    });
    expect(find.text('Pick your AI'), findsOneWidget);
    expect(find.text('Ask it anything'), findsOneWidget);
    expect(find.byKey(const Key('step-error')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('faq expands and collapses an item', (tester) async {
    await _pump(tester, {
      'type': 'faq',
      'items': [
        {'question': 'Is it free?', 'answer': 'Yes, totally.'},
      ],
    });
    expect(find.text('Yes, totally.'), findsNothing);
    await tester.tap(find.text('Is it free?'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, totally.'), findsOneWidget);
    await tester.tap(find.text('Is it free?'));
    await tester.pumpAndSettle();
    expect(find.text('Yes, totally.'), findsNothing);
  });

  testWidgets('tabs shows the selected tab and switches on tap', (tester) async {
    await _pump(tester, {
      'type': 'tabs',
      'tabs': [
        {
          'label': 'Web',
          'blocks': [{'type': 'text', 'body': 'web steps'}],
        },
        {
          'label': 'Desktop',
          'blocks': [{'type': 'text', 'body': 'desktop steps'}],
        },
      ],
    });
    expect(find.text('web steps'), findsOneWidget);
    expect(find.text('desktop steps'), findsNothing);
    await tester.tap(find.text('Desktop'));
    await tester.pumpAndSettle();
    expect(find.text('desktop steps'), findsOneWidget);
    expect(find.text('web steps'), findsNothing);
  });
}
