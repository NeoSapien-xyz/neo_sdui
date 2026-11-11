import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui/src/blocks/_icon.dart';

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
  testWidgets('header renders title + subtitle in themed slots', (tester) async {
    await _pump(tester, {'type': 'header', 'title': 'Hi', 'subtitle': 'sub'});
    expect(tester.widget<Text>(find.text('Hi')).style, _theme.title);
    expect(tester.widget<Text>(find.text('sub')).style, _theme.subtitle);
  });

  testWidgets('header without subtitle omits it', (tester) async {
    await _pump(tester, {'type': 'header', 'title': 'Hi'});
    expect(find.text('Hi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header tone:accent tints the title with the accent role',
      (tester) async {
    await _pump(tester, {'type': 'header', 'title': 'Hi', 'tone': 'accent'});
    expect(tester.widget<Text>(find.text('Hi')).style!.color, _theme.accent);
  });

  testWidgets('header icon:"export" resolves the package-drawn export glyph',
      (tester) async {
    // Regression guard: `export` is a package-drawn glyph (kDrawnIcons — the
    // figma up-arrow-out-of-a-tray), not the Material `Icons.ios_share` it used
    // to map to. Guards the kDrawnIcons registration + the _drawnIcon switch.
    await _pump(tester,
        {'type': 'header', 'title': 'Export data', 'tone': 'accent', 'icon': 'export'});
    expect(find.byKey(const Key('icon-export')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text uses body; emphasis low renders muted', (tester) async {
    await _pump(tester, {'type': 'text', 'body': 'B'});
    expect(tester.widget<Text>(find.text('B')).style, _theme.body);
    await _pump(tester, {'type': 'text', 'body': 'M', 'emphasis': 'low'});
    expect(tester.widget<Text>(find.text('M')).style!.color, _theme.textMuted);
  });

  testWidgets('cta tap emits its parsed action', (tester) async {
    NeoAction? got;
    await _pump(
      tester,
      {'type': 'cta', 'label': 'Go', 'action': 'https://neo.xyz'},
      onAction: (_, a) => got = a,
    );
    await tester.tap(find.text('Go'));
    expect(got, isA<ExternalUrl>());
    expect((got as ExternalUrl).url.host, 'neo.xyz');
  });

  Color? decorColor(WidgetTester tester, Color want) {
    for (final b in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
      final c = (b.decoration as BoxDecoration).color;
      if (c == want) return c;
    }
    return null;
  }

  testWidgets('cta derives fill/text from emphasis', (tester) async {
    await _pump(tester, {'type': 'cta', 'label': 'Hi', 'action': 'route:x', 'emphasis': 'high'});
    expect(decorColor(tester, _theme.accent), _theme.accent); // filled accent
    expect(tester.widget<Text>(find.text('Hi')).style!.color, _theme.onAccent);
  });

  testWidgets('callout surface derives from tone', (tester) async {
    await _pump(tester, {'type': 'callout', 'tone': 'critical', 'bullets': ['x']});
    expect(decorColor(tester, _theme.toneSurface('critical')), isNotNull);
  });

  testWidgets('swapping the palette re-skins with no wire change', (tester) async {
    const brand = Color(0xFF123456);
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
                  'blocks': [{'type': 'cta', 'label': 'Go', 'action': 'route:x', 'emphasis': 'high'}],
                }),
                theme: _theme.copyWith(accent: brand),
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(decorColor(tester, brand), brand); // same JSON, new accent
  });

  testWidgets('callout renders its title and every bullet', (tester) async {
    await _pump(tester, {
      'type': 'callout',
      'title': 'Heads up',
      'bullets': ['one', 'two', 'three'],
    });
    expect(find.text('Heads up'), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets('callout with non-string bullets and no title paints nothing',
      (tester) async {
    await _pump(tester, {
      'type': 'callout',
      'bullets': [{'text': 'oops, an object'}], // slip: objects, not strings
    });
    expect(tester.takeException(), isNull);
    expect(find.byType(DecoratedBox), findsNothing); // no stray tinted square
  });

  testWidgets('callout with bullets as a bare string keeps its title, no throw',
      (tester) async {
    await _pump(tester, {'type': 'callout', 'title': 'Note', 'bullets': 'nope'});
    expect(tester.takeException(), isNull);
    expect(find.text('Note'), findsOneWidget); // title survives the bad bullets
  });

  testWidgets('AE4: media without ratio uses the default 358/221',
      (tester) async {
    await _pump(tester, {'type': 'media', 'url': 'https://x/y.png'});
    await tester.pumpAndSettle();
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        358 / 221);
    tester.takeException();
  });

  testWidgets('media derives ratio from width/height', (tester) async {
    await _pump(tester,
        {'type': 'media', 'url': 'https://x/y.png', 'width': 4, 'height': 3});
    await tester.pumpAndSettle();
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        4 / 3);
    tester.takeException();
  });

  testWidgets('explicit ratio wins over width/height', (tester) async {
    await _pump(tester, {
      'type': 'media',
      'url': 'https://x/y.png',
      'ratio': 2.0,
      'width': 4,
      'height': 3,
    });
    await tester.pumpAndSettle();
    expect(tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio, 2.0);
    tester.takeException();
  });

  testWidgets('media wires fade + error builders and shows error placeholder',
      (tester) async {
    await _pump(tester, {'type': 'media', 'url': 'https://x/y.png'});
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.frameBuilder, isNotNull);
    expect(img.errorBuilder, isNotNull);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('media-error')), findsOneWidget);
    tester.takeException();
  });

  testWidgets('code renders content in the mono role and captions its label',
      (tester) async {
    await _pump(tester,
        {'type': 'code', 'label': 'Your MCP server', 'content': 'npm i -g x'});
    final content = tester.widget<Text>(find.text('npm i -g x')).style!;
    expect(content.color, _theme.textPrimary);
    expect(content.fontFamilyFallback, _theme.mono.fontFamilyFallback);
    expect(tester.widget<Text>(find.text('Your MCP server')).style, _theme.caption);
  });

  testWidgets('code without a label omits it', (tester) async {
    await _pump(tester, {'type': 'code', 'content': 'x'});
    expect(find.text('x'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('code copies its content to the clipboard and confirms',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await _pump(tester, {'type': 'code', 'content': 'claude mcp list'});
    await tester.tap(find.byKey(const Key('code-copy')));
    await tester.pump(); // run the copy future
    await tester.pump(); // apply the "Copied" setState
    expect(copied, 'claude mcp list');
    expect(find.text('Copied'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // fire + clear the reset timer
    expect(find.text('Copy'), findsOneWidget);
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('glyphs', () {
    Future<void> pumpIcon(WidgetTester t, NeoSduiTheme theme) => t.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: leadingIcon(theme, 'help', 'accent', size: 20)),
          ),
        );

    testWidgets('a theme glyph wins over the default icon and gets size + colour',
        (t) async {
      double? gotSize;
      Color? gotColor;
      final theme = _theme.copyWith(glyphs: {
        'help': (size, color) {
          gotSize = size;
          gotColor = color;
          return SizedBox.square(key: const Key('mine'), dimension: size);
        },
      });
      await pumpIcon(t, theme);
      expect(find.byKey(const Key('mine')), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(gotSize, 20);
      expect(gotColor, theme.toneColor('accent'));
    });

    testWidgets('no glyph entry: help still renders the Material icon',
        (t) async {
      await pumpIcon(t, _theme);
      expect(t.widget<Icon>(find.byType(Icon)).icon, kDefaultIcons['help']);
    });

    for (final (key, build) in <(String, Widget Function(Color))>[
      ('icon-chevron-down', (c) => NeoChevronDownIcon(size: 24, color: c)),
      ('icon-copy', (c) => NeoCopyIcon(size: 24, color: c)),
      ('icon-check', (c) => NeoCheckIcon(size: 24, color: c)),
    ]) {
      testWidgets('$key paints inside its square in the given colour',
          (t) async {
        const c = Color(0xFF123456);
        await t.pumpWidget(Directionality(
            textDirection: TextDirection.ltr, child: Center(child: build(c))));
        final f = find.byKey(Key(key));
        expect(t.getSize(f), const Size.square(24));
        expect(t.renderObject<RenderBox>(f).paintBounds,
            const Rect.fromLTWH(0, 0, 24, 24));
        expect(f, paints..path(color: c));
      });
    }
  });

  group('header and text roles', () {
    Future<void> pumpThemed(
        WidgetTester t, NeoSduiTheme theme, Map<String, Object?> block) =>
        t.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: NeoSduiView(
              document:
                  NeoDocument.fromJson({'version': 1, 'blocks': [block]}),
              theme: theme,
              onAction: (_, _) {},
            ),
          ),
        ));
    TextStyle? styleOf(WidgetTester t, String s) =>
        t.widget<Text>(find.text(s)).style;

    testWidgets('footnote uses the footnote role when set', (t) async {
      const role = TextStyle(fontSize: 11, color: Color(0xFF123456));
      await pumpThemed(t, _theme.copyWith(footnote: role),
          {'type': 'text', 'body': 'Note', 'variant': 'footnote'});
      expect(styleOf(t, 'Note')!.fontSize, 11);
      expect(styleOf(t, 'Note')!.color, const Color(0xFF123456));
    });

    testWidgets('footnote unset keeps the muted caption', (t) async {
      await pumpThemed(t, _theme,
          {'type': 'text', 'body': 'Note', 'variant': 'footnote'});
      expect(styleOf(t, 'Note')!.fontSize, _theme.caption.fontSize);
      expect(styleOf(t, 'Note')!.color, _theme.textMuted);
    });

    testWidgets('paragraph role styles normal text', (t) async {
      const role = TextStyle(fontSize: 17, color: Color(0xFF654321));
      await pumpThemed(t, _theme.copyWith(paragraph: role),
          {'type': 'text', 'body': 'Body'});
      expect(styleOf(t, 'Body')!.fontSize, 17);
    });

    testWidgets('low emphasis stays muted body with a paragraph role',
        (t) async {
      await pumpThemed(
          t,
          _theme.copyWith(paragraph: const TextStyle(fontSize: 17)),
          {'type': 'text', 'body': 'Low', 'emphasis': 'low'});
      expect(styleOf(t, 'Low')!.color, _theme.textMuted);
    });

    Map<String, Object?> compactHeader() => {
          'type': 'group',
          'children': [
            {
              'type': 'header',
              'title': 'H',
              'subtitle': 'S',
              'icon': 'check',
            },
          ],
        };

    testWidgets('compact header uses rowTitle, icon size/gap, subtitle gap',
        (t) async {
      const role = TextStyle(fontSize: 19, color: Color(0xFF0000FF));
      final themed = _theme.copyWith(
        rowTitle: role,
        header: const NeoHeaderStyle(
            subtitleGap: 10, compactIconSize: 30, compactIconGap: 14),
      );
      await pumpThemed(t, themed, compactHeader());
      expect(styleOf(t, 'H')!.fontSize, 19);
      final h = t.getRect(find.text('H'));
      final s = t.getRect(find.text('S'));
      expect(s.top - h.bottom, greaterThanOrEqualTo(10));
      final icon = t.getRect(find.byType(Icon).first);
      expect(icon.width, 30);
      expect(h.left - icon.right, 14);
    });

    testWidgets('compact header default: body at w500 primary, gap 4',
        (t) async {
      await pumpThemed(t, _theme, compactHeader());
      expect(styleOf(t, 'H')!.fontSize, _theme.body.fontSize);
      expect(styleOf(t, 'H')!.fontWeight, FontWeight.w500);
      final icon = t.getRect(find.byType(Icon).first);
      expect(icon.width, _theme.body.fontSize);
      expect(t.getRect(find.text('H')).left - icon.right, _theme.spaceSm);
    });
  });
}
