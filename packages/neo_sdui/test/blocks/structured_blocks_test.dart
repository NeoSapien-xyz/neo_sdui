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

  testWidgets(
      'a step reserves its image box behind a shimmer, collapsing only on failure',
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
    // Pending: the ratio box is reserved up front behind a shimmer, so the card
    // never grows when the frame finally lands (the "image pops in and expands
    // the card" jump).
    expect(find.text('Open your tool\'s MCP settings'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget); // the step image
    expect(find.byKey(const Key('media-shimmer')), findsOneWidget);
    expect(
      tester
          .widgetList<AspectRatio>(find.byType(AspectRatio))
          .map((a) => a.aspectRatio),
      contains(1.6),
    );
    expect(find.text('1'), findsOneWidget); // numbering intact

    // Genuine failure (deterministic in tests) -> collapse: no empty ratio box,
    // so an unpublished asset leaves the caption standing alone.
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byKey(const Key('media-shimmer')), findsNothing);
    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('callout draws a theme-mapped leading icon, tinted by tone', (tester) async {
    // A Material-mapped icon name (kDefaultIcons) resolves to an Icon, tinted by
    // tone. (`export` is now a package-drawn glyph — see the leaf-blocks test.)
    await _pump(tester, {
      'type': 'callout',
      'tone': 'accent',
      'icon': 'download',
      'title': 'Requires laptop for setup',
      'bullets': ['Works everywhere once connected.'],
    });
    expect(find.byIcon(Icons.download), findsOneWidget);
    // Tinted by tone: accent -> the accent role color.
    expect(
      tester.widget<Icon>(find.byIcon(Icons.download)).color,
      _theme.accent,
    );
    expect(find.text('Requires laptop for setup'), findsOneWidget);
  });

  testWidgets('the sparkle icon paints the drawn NeoSapien star, not a Material glyph',
      (tester) async {
    // `sparkle` isn't a font glyph — the package draws the two-pointed brand star
    // (figma "Bold / Weather / Stars"); `Icons.auto_awesome` was a wrong match.
    await _pump(tester, {
      'type': 'callout',
      'tone': 'accent',
      'icon': 'sparkle',
      'title': 'Not getting results?',
    });
    expect(find.byKey(const Key('icon-sparkle')), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsNothing);
  });

  testWidgets('an unmapped icon name draws nothing (graceful)', (tester) async {
    await _pump(tester, {'type': 'callout', 'icon': 'no-such-glyph', 'title': 'x'});
    expect(find.byType(Icon), findsNothing);
    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('an accent callout sits on plain surface with a gradient bullet run',
      (tester) async {
    const grad = LinearGradient(colors: [Color(0xFF00F1A0), Color(0xFF008B5C)]);
    final theme = NeoSduiTheme.fallback()
        .copyWith(accentGradient: grad, stepCardBorderColor: const Color(0x08FFFFFF));
    await _pumpThemed(
      tester,
      {
        'type': 'callout',
        'tone': 'accent',
        'icon': 'sparkle',
        'title': 'Not getting results?',
        'bullets': [
          ['Add ', {'text': 'from NeoSapien', 'tone': 'accent'}, ' to your message.'],
        ],
      },
      theme,
    );
    // The box is the plain surface, NOT the accent tint (no green box).
    final boxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == theme.surface)
        .toList();
    expect(boxes, isNotEmpty);
    expect(
      boxes.every((d) => d.color != theme.toneSurface('accent')),
      isTrue,
    );
    // The accent phrase in the bullet rides a gradient ShaderMask (run support).
    expect(find.byType(ShaderMask), findsWidgets);
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
  final gridFinder = find.byWidgetPredicate(
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

  final gridTheme =
      NeoSduiTheme.fallback().copyWith(gridLine: const Color(0x14FFFFFF));

  testWidgets('a featured group paints the grid behind its children', (tester) async {
    await pumpGroup(tester, {
      'type': 'group',
      'emphasis': 'high',
      'children': [
        {'type': 'code', 'content': 'claude mcp add neosapien'},
      ],
    }, gridTheme);
    expect(gridFinder, findsOneWidget);
    expect(find.text('claude mcp add neosapien'), findsOneWidget); // content on top
  });

  testWidgets('a plain (non-featured) group paints no grid', (tester) async {
    await pumpGroup(tester, {
      'type': 'group',
      'children': [
        {'type': 'text', 'body': 'flat'},
      ],
    }, gridTheme);
    expect(gridFinder, findsNothing);
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
    expect(gridFinder, findsNothing);
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

  testWidgets('steps layout:row lays the steps side by side with badges',
      (tester) async {
    await _pump(tester, {
      'type': 'steps',
      'layout': 'row',
      'items': [
        {'caption': 'Pick your AI'},
        {'caption': 'Follow the quick guide'},
        {'caption': 'Ask it anything'},
      ],
    });
    // Equal-width cells -> one Expanded per step (the vertical layout wraps in
    // Padding, never Expanded).
    expect(find.byType(Expanded), findsNWidgets(3));
    expect(find.text('Pick your AI'), findsOneWidget);
    expect(find.text('Ask it anything'), findsOneWidget);
    // Numbered badges intact.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('steps layout:row boxes each cell when the theme sets a step card',
      (tester) async {
    const fill = Color(0x05FFFFFF);
    const border = Color(0x08FFFFFF);
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'layout': 'row',
        'items': [
          {'caption': 'Pick your AI'},
          {'caption': 'Follow the quick guide'},
          {'caption': 'Ask it anything'},
        ],
      },
      NeoSduiTheme.fallback()
          .copyWith(stepCardColor: fill, stepCardBorderColor: border),
    );
    // Equal-height boxes -> the row is wrapped in IntrinsicHeight.
    expect(find.byType(IntrinsicHeight), findsOneWidget);
    // Each of the 3 cells is a card filled with stepCardColor + a hairline
    // border (badges are Containers too, but carry no fill -> filtered out).
    final cards = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == fill)
        .toList();
    expect(cards, hasLength(3));
    expect(cards.first.border, Border.all(color: border));
  });

  testWidgets('vertical steps box each item as a card when the theme sets a step card',
      (tester) async {
    const surface = Color(0xFF123456);
    const border = Color(0x08FFFFFF);
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {'caption': 'Open settings', 'detail': 'on your laptop'},
          {'caption': 'Sign in'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(
        surface: surface,
        stepCardColor: const Color(0x05FFFFFF),
        stepCardBorderColor: border,
      ),
    );
    // Each item is a `surface`-filled card with a hairline border (the how_to
    // List Item) — distinct from the row strip's faint stepCardColor fill.
    final cards = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == surface)
        .toList();
    expect(cards, hasLength(2));
    expect(cards.first.border, Border.all(color: border));
    // The muted "Step n:" label replaces the inline number badge — 0-indexed to
    // match the figma numbering ("Step 0:", "Step 1:", …).
    expect(find.text('Step 0:'), findsOneWidget);
    expect(find.text('Step 1:'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('a carded step underlines a URL in its caption', (tester) async {
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {'caption': 'Open chatgpt.com in your laptop browser'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(stepCardColor: const Color(0x05FFFFFF)),
    );
    // "Step 0:" label (0-indexed) + the caption text render.
    expect(find.text('Step 0:'), findsOneWidget);
    expect(
      find.textContaining('chatgpt.com', findRichText: true),
      findsOneWidget,
    );
    // The URL substring is drawn underlined.
    bool underlined(InlineSpan s) {
      if (s is TextSpan) {
        if (s.style?.decoration == TextDecoration.underline) return true;
        return (s.children ?? const <InlineSpan>[]).any(underlined);
      }
      return false;
    }

    final anyUnderline = tester
        .widgetList<RichText>(find.byType(RichText))
        .any((rt) => underlined(rt.text));
    expect(anyUnderline, isTrue);
  });

  testWidgets('a carded step with a screenshot echoes its command inline, no copy chip',
      (tester) async {
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {
            'caption': 'Ensure Claude Code CLI is installed:',
            'code': 'npm install -g @anthropic-ai/claude-code',
            'image': 'https://cdn.neosapien.xyz/mcp/code-0.png',
            'ratio': 2.8,
          },
        ],
      },
      NeoSduiTheme.fallback().copyWith(stepCardColor: const Color(0x05FFFFFF)),
    );
    // The command rides inline in the caption's rich text (no boxed copy chip,
    // no hero command card).
    expect(
      find.textContaining('npm install -g @anthropic-ai/claude-code',
          findRichText: true),
      findsOneWidget,
    );
    expect(find.byKey(const Key('code-copy')), findsNothing);
    expect(find.byKey(const Key('command-card')), findsNothing);
  });

  testWidgets('an emphasis:high command step is a copyable hero card',
      (tester) async {
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {
            'caption': 'Open terminal, run Claude and then run this command:',
            'code': 'claude mcp add --transport http neosapien',
            'emphasis': 'high',
          },
        ],
      },
      NeoSduiTheme.fallback().copyWith(stepCardColor: const Color(0x05FFFFFF)),
    );
    // The command is the hero card (centered mono + "Copy Command"), never the
    // old inline copy chip.
    expect(find.byKey(const Key('command-card')), findsOneWidget);
    expect(find.byKey(const Key('code-copy')), findsNothing);
    expect(find.text('Copy Command'), findsOneWidget);
    // ...and the command also echoes inline in the caption — so it renders
    // twice: once in the hero card, once in the step sentence (the figma shows
    // both).
    expect(
      find.textContaining('claude mcp add --transport http neosapien',
          findRichText: true),
      findsNWidgets(2),
    );
  });

  testWidgets('the hero command card rides commandStyle when the theme sets it',
      (tester) async {
    // The role's non-null path (R8/#3): a theme that sets commandStyle sizes the
    // hero command by it, not the `mono` fallback.
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {'caption': 'run:', 'code': 'claude mcp add x', 'emphasis': 'high'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(
        stepCardColor: const Color(0x05FFFFFF),
        commandStyle: const TextStyle(fontSize: 88),
      ),
    );
    final cmd = tester.widget<Text>(find.byKey(const Key('command-card')));
    expect(cmd.style!.fontSize, 88); // the role, not resolvedCommandStyle's mono fallback
  });

  testWidgets('a callout bullet rides calloutBody when the theme sets it',
      (tester) async {
    // The role's non-null path (#3): a theme that sets calloutBody sizes the
    // bullet by it, not the `body` fallback.
    await _pumpThemed(
      tester,
      {
        'type': 'callout',
        'bullets': ['Export all memories'],
      },
      NeoSduiTheme.fallback().copyWith(calloutBody: const TextStyle(fontSize: 99)),
    );
    expect(
      tester.widget<Text>(find.text('Export all memories')).style!.fontSize,
      99,
    );
  });

  testWidgets('the copy button foot color derives from the theme cardGradient',
      (tester) async {
    // #4: the flat-pill fix reads the cardGradient's dark stop as its foot color.
    const cardGrad = LinearGradient(colors: [Color(0xFF202423), Color(0xFF171A19)]);
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {'caption': 'run:', 'code': 'claude mcp add x', 'emphasis': 'high'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(
        stepCardColor: const Color(0x05FFFFFF),
        cardGradient: cardGrad,
      ),
    );
    final box = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Copy Command'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final grad = (box.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(grad.colors.last, cardGrad.colors.last); // the cardGradient foot, not theme.surface
  });

  testWidgets('a carded step that throws is isolated by the R8 catch; siblings survive',
      (tester) async {
    // #2: force a synchronous throw inside `_cardedItem` — a nested `blocks`
    // entry that is a Map with a non-String key trips `Map<String,Object?>.from`.
    // The R8 try/catch must degrade just that item to a `step-error` placeholder
    // (keeping its number) while a sibling carded item still renders.
    await _pumpThemed(
      tester,
      {
        'type': 'steps',
        'items': [
          {'caption': 'Good step'},
          {
            'caption': 'Boom',
            'blocks': [
              {42: 'non-string key throws in Map<String,Object?>.from'},
            ],
          },
        ],
      },
      NeoSduiTheme.fallback().copyWith(stepCardColor: const Color(0x05FFFFFF)),
    );
    expect(tester.takeException(), isNull); // caught, not propagated to the block
    expect(find.byKey(const Key('step-error')), findsOneWidget);
    expect(find.text('Good step'), findsOneWidget); // the sibling still renders
  });

  testWidgets('a group heading with no tone reads as primary, not muted body',
      (tester) async {
    const muted = Color(0xFF868686);
    const primary = Color(0xFFFFFFFF);
    await _pumpThemed(
      tester,
      {
        'type': 'group',
        'children': [
          {'type': 'header', 'title': 'Still having issues?'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(
        body: const TextStyle(fontSize: 15, color: muted),
        textPrimary: primary,
      ),
    );
    // A sub-heading is still a heading — primary, not the dim body color.
    expect(
      tester.widget<Text>(find.text('Still having issues?')).style?.color,
      primary,
    );
  });

  testWidgets('a warning-toned heading paints the theme warning color',
      (tester) async {
    const warn = Color(0xFFFFC107);
    await _pumpThemed(
      tester,
      {
        'type': 'group',
        'children': [
          {'type': 'header', 'tone': 'warning', 'title': 'MCP server timeout'},
        ],
      },
      NeoSduiTheme.fallback().copyWith(warning: warn),
    );
    expect(
      tester.widget<Text>(find.text('MCP server timeout')).style?.color,
      warn,
    );
  });

  testWidgets('a header nested in a group drops from section to item scale',
      (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(
      title: const TextStyle(fontSize: 30, color: Color(0xFFFFFFFF)),
      body: const TextStyle(fontSize: 15, color: Color(0xFFFFFFFF)),
    );
    // Top-level header keeps the section title scale.
    await _pumpThemed(tester, {'type': 'header', 'title': 'Section'}, theme);
    expect(tester.widget<Text>(find.text('Section')).style?.fontSize, 30);
    // The same header inside a group card drops to the item label scale — the
    // theme's `body` role, at heading weight. The scale is the *theme's* 15, not
    // a size baked in the block: this asserted 14 while the theme said 15, which
    // is how a fabricated figma constant survived every test in the suite.
    await _pumpThemed(tester, {
      'type': 'group',
      'children': [
        {'type': 'header', 'title': 'Item'},
      ],
    }, theme);
    final item = tester.widget<Text>(find.text('Item')).style;
    expect(item?.fontSize, 15);
    expect(item?.fontWeight, FontWeight.w500);
  });

  testWidgets('a spacer variant:rule draws a themed dashed hairline',
      (tester) async {
    const line = Color(0xFF334033);
    await _pumpThemed(tester, {'type': 'spacer', 'variant': 'rule'},
        NeoSduiTheme.fallback().copyWith(divider: line));
    final rule = tester.widget<CustomPaint>(find.byWidgetPredicate((w) =>
        w is CustomPaint &&
        w.painter.runtimeType.toString() == '_DashedLinePainter'));
    expect((rule.painter as dynamic).color, line);
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

  testWidgets('a group variant:list draws one card of flat icon+label+caret rows',
      (tester) async {
    NeoAction? tapped;
    await _pump(
      tester,
      {
        'type': 'group',
        'variant': 'list',
        'children': [
          {
            'type': 'card',
            'title': 'Troubleshooting',
            'icon': 'help',
            'action': 'route:troubleshooting',
          },
          {'type': 'card', 'title': 'FAQs', 'icon': 'chat', 'action': 'route:faq'},
        ],
      },
      onAction: (_, a) => tapped = a,
    );
    // Both rows: label + leading glyph + caret, all inside the one list card.
    expect(find.text('Troubleshooting'), findsOneWidget);
    expect(find.text('FAQs'), findsOneWidget);
    expect(find.text('›'), findsNWidgets(2));
    expect(find.byType(Icon), findsNWidgets(2));
    // A listed row is flat + tappable (the group owns the surface).
    await tester.tap(find.text('FAQs'));
    expect(tapped, isA<RouteAction>());
  });

  testWidgets('a group of only cards lists automatically (no variant needed)',
      (tester) async {
    await _pump(tester, {
      'type': 'group',
      'children': [
        {'type': 'card', 'title': 'Troubleshooting', 'icon': 'help', 'action': 'route:t'},
        {'type': 'card', 'title': 'FAQs', 'icon': 'chat', 'action': 'route:f'},
      ],
    });
    // Same flat rows even though the wire omits variant:"list".
    expect(find.text('Troubleshooting'), findsOneWidget);
    expect(find.text('FAQs'), findsOneWidget);
    expect(find.byType(Icon), findsNWidgets(2));
    expect(find.text('›'), findsNWidgets(2));
  });

  testWidgets('a step renders nested blocks (a grid card wrapping a code block)',
      (tester) async {
    const cmd =
        'claude mcp add --transport http neosapien https://api.neosapien.xyz/mcp';
    await pumpGroup(tester, {
      'type': 'steps',
      'items': [
        {
          'caption': 'Add to Claude Code',
          'blocks': [
            {
              'type': 'group',
              'emphasis': 'high',
              'children': [
                {'type': 'code', 'content': cmd},
              ],
            },
          ],
        },
      ],
    }, gridTheme);
    expect(find.text('Add to Claude Code'), findsOneWidget); // the caption
    expect(find.text(cmd), findsOneWidget); // the nested code block
    expect(gridFinder, findsOneWidget); // the nested featured group's grid
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
