import 'package:flutter/material.dart' show Icons;
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

  testWidgets('a featured card (emphasis:high) fills with the theme card gradient',
      (tester) async {
    const grad = LinearGradient(colors: [Color(0xFF203020), Color(0xFF101810)]);
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
                    {'type': 'card', 'emphasis': 'high', 'title': 'ChatGPT', 'action': 'screen:chatgpt'},
                    {'type': 'card', 'title': 'FAQs', 'action': 'screen:faq'},
                  ],
                }),
                theme: _theme.copyWith(cardGradient: grad),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    final decos = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<ShapeDecoration>()
        .toList();
    // Featured card fills with the gradient; the plain card stays the flat color.
    expect(decos.any((d) => d.gradient == grad), isTrue);
    expect(
      decos.any((d) => d.gradient == null && d.color == _theme.resolvedCardColor),
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

  testWidgets('a step renders its optional full-width image above the row',
      (tester) async {
    await _pump(tester, {
      'type': 'steps',
      'items': [
        {
          'caption': 'Open your tool\'s MCP settings',
          'image': 'https://cdn.neosapien.xyz/mcp/other-0.png',
          'ratio': 1.6,
        },
      ],
    });
    tester.takeException(); // deterministic network-image error
    expect(find.text('Open your tool\'s MCP settings'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // the step image
    // A failed/pending asset collapses (no empty ratio box) so the caption still
    // stands alone until the CDN image is published.
    expect(find.byType(AspectRatio), findsNothing);
    expect(find.text('1'), findsOneWidget); // numbering intact
  });

  testWidgets('callout draws a leading icon named on the wire', (tester) async {
    await _pump(tester, {
      'type': 'callout',
      'tone': 'accent',
      'icon': 'sparkle',
      'title': 'Requires laptop for setup',
      'bullets': ['Works everywhere once connected.'],
    });
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    // Tinted by tone: accent -> the accent role color.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.auto_awesome)).color,
      _theme.accent,
    );
    expect(find.text('Requires laptop for setup'), findsOneWidget);
  });

  testWidgets('an unmapped icon name draws nothing (graceful)', (tester) async {
    await _pump(tester, {'type': 'callout', 'icon': 'no-such-glyph', 'title': 'x'});
    expect(find.byType(Icon), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('header draws a leading icon named on the wire', (tester) async {
    await _pump(tester,
        {'type': 'header', 'tone': 'accent', 'icon': 'download', 'title': 'Export data'});
    expect(find.byIcon(Icons.download), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
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

  // A featured group paints the theme's grid behind its children; a plain group,
  // or a null gridLine, stays flat. The grid is theme data, never on the wire.
  final _gridFinder = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter.runtimeType.toString() == 'GridPainter',
  );

  Future<void> pumpGroup(
    WidgetTester tester,
    Map<String, Object?> block,
    NeoSduiTheme theme,
  ) =>
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
                  document: NeoDocument.fromJson({'version': 1, 'blocks': [block]}),
                  theme: theme,
                  onAction: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );

  final _gridTheme =
      NeoSduiTheme.fallback().copyWith(gridLine: const Color(0x14FFFFFF));

  testWidgets('a featured group paints the grid behind its children', (tester) async {
    await pumpGroup(tester, {
      'type': 'group',
      'emphasis': 'high',
      'children': [
        {'type': 'code', 'content': 'claude mcp add neosapien'},
      ],
    }, _gridTheme);
    expect(_gridFinder, findsOneWidget);
    expect(find.text('claude mcp add neosapien'), findsOneWidget); // content on top
  });

  testWidgets('a plain (non-featured) group paints no grid', (tester) async {
    await pumpGroup(tester, {
      'type': 'group',
      'children': [
        {'type': 'text', 'body': 'flat'},
      ],
    }, _gridTheme);
    expect(_gridFinder, findsNothing);
    expect(find.text('flat'), findsOneWidget);
  });

  testWidgets('a featured group with no theme gridLine stays flat', (tester) async {
    await pumpGroup(tester, {
      'type': 'group',
      'emphasis': 'high',
      'children': [
        {'type': 'text', 'body': 'flat'},
      ],
    }, NeoSduiTheme.fallback());
    expect(_gridFinder, findsNothing);
    expect(find.text('flat'), findsOneWidget);
  });

  testWidgets('a featured group fills with the theme group gradient', (tester) async {
    const grad = LinearGradient(colors: [Color(0xFF14201A), Color(0xFF0A100D)]);
    await pumpGroup(tester, {
      'type': 'group',
      'emphasis': 'high',
      'children': [
        {'type': 'text', 'body': 'hero'},
      ],
    }, NeoSduiTheme.fallback().copyWith(groupGradient: grad));
    // Default (no `shape`) group -> BoxDecoration; the featured fill is the
    // gradient, not the flat surface color.
    final decos = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    expect(decos.any((d) => d.gradient == grad && d.color == null), isTrue);
    expect(find.text('hero'), findsOneWidget);
  });

  testWidgets('a plain (non-featured) group ignores the group gradient', (tester) async {
    const grad = LinearGradient(colors: [Color(0xFF14201A), Color(0xFF0A100D)]);
    await pumpGroup(tester, {
      'type': 'group',
      'children': [
        {'type': 'text', 'body': 'flat'},
      ],
    }, NeoSduiTheme.fallback().copyWith(groupGradient: grad));
    final decos = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>();
    expect(decos.any((d) => d.gradient == grad), isFalse);
  });

  testWidgets('a spacer variant:rule draws a themed hairline', (tester) async {
    const line = Color(0xFF334033);
    await _pumpThemed(tester, {'type': 'spacer', 'variant': 'rule'},
        NeoSduiTheme.fallback().copyWith(divider: line));
    final rule = tester.widget<Container>(find.byType(Container));
    expect(rule.color, line);
  });

  testWidgets('a plain spacer draws no line', (tester) async {
    await _pump(tester, {'type': 'spacer'});
    expect(find.byType(Container), findsNothing);
  });

  testWidgets('a card actionLabel replaces the caret and still taps', (tester) async {
    NeoAction? got;
    await _pump(
      tester,
      {
        'type': 'card',
        'title': 'ChatGPT',
        'action': 'route:chatgpt',
        'actionLabel': 'Open Guide →',
      },
      onAction: (_, a) => got = a,
    );
    expect(find.text('Open Guide →'), findsOneWidget);
    expect(find.text('›'), findsNothing);
    await tester.tap(find.text('ChatGPT'));
    expect(got, isA<RouteAction>());
  });
}

Future<void> _pumpThemed(
  WidgetTester tester,
  Map<String, Object?> block,
  NeoSduiTheme theme,
) =>
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
                document: NeoDocument.fromJson({'version': 1, 'blocks': [block]}),
                theme: theme,
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
