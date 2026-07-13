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

  testWidgets('tile card draws an image-top surface with the themed shape + shadow',
      (tester) async {
    const glow = [BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 10)];
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
                document: NeoDocument.fromJson({
                  'version': 1,
                  'blocks': [
                    {
                      'type': 'card',
                      'variant': 'tile',
                      'ratio': 1.3333,
                      'thumb': 'https://x/y.png',
                      'title': 'How can I control Neo 1?',
                      'action': 'sheet:control',
                    },
                  ],
                }),
                theme: _theme.copyWith(cardShadow: glow),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    tester.takeException(); // deterministic network-image error

    // Image-top tile: a full-width thumbnail box above the details.
    expect(find.byType(AspectRatio), findsWidgets);
    // The surface carries the client's squircle + glow, off the wire.
    final shapes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<ShapeDecoration>();
    expect(
      shapes.any((d) =>
          d.shape is RoundedSuperellipseBorder && d.shadows == glow),
      isTrue,
    );
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

  testWidgets('a step renders its optional detail line and copyable command',
      (tester) async {
    await _pump(tester, {
      'type': 'steps',
      'items': [
        {
          'caption': 'Install Claude Code',
          'detail': 'one-time',
          'code': 'npm install -g @anthropic-ai/claude-code',
        },
      ],
    });
    expect(find.text('Install Claude Code'), findsOneWidget);
    expect(find.text('one-time'), findsOneWidget);
    expect(find.text('npm install -g @anthropic-ai/claude-code'), findsOneWidget);
    expect(find.byKey(const Key('code-copy')), findsOneWidget); // the Copy chip
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

  testWidgets('faq with a non-string question/answer degrades, does not crash',
      (tester) async {
    await _pump(tester, {
      'type': 'faq',
      'items': [
        {'question': 2024, 'answer': 'x'}, // numeric question (first-render path)
        {'question': 'How many?', 'answer': 10}, // numeric answer (open path)
      ],
    });
    expect(tester.takeException(), isNull); // no red ErrorWidget on first render
    await tester.tap(find.text('How many?')); // opening casts the numeric answer
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
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
