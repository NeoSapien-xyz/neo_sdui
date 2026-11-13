import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

BlockRegistry _testRegistry() {
  final r = BlockRegistry.empty();
  r.register('text', (c, n) => Text(n.stringOr('body', '')!));
  r.register('boom', (c, n) => throw StateError('boom'));
  r.register(
    'cta',
    (c, n) => GestureDetector(
      onTap: () =>
          NeoSduiScope.of(c).dispatch(c, NeoAction.parse(n.stringOr('action', '')!)),
      child: Text(n.stringOr('label', '')!),
    ),
  );
  return r;
}

NeoDocument _doc(List<Map<String, Object?>> blocks,
        {Map<String, Object?>? views}) =>
    NeoDocument.fromJson({
      'version': 1,
      'blocks': blocks,
      'views': ?views,
    });

Future<void> _pump(
  WidgetTester tester,
  NeoDocument doc, {
  NeoDocument? defaultDoc,
  NeoActionHandler? onAction,
  NeoSduiTheme? theme,
  BlockRegistry? registry,
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
              document: doc,
              theme: theme ?? NeoSduiTheme.fallback(),
              registry: registry ?? _testRegistry(),
              defaultDocument: defaultDoc,
              onAction: onAction ?? (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders blocks in order', (tester) async {
    await _pump(tester, _doc([
      {'type': 'text', 'body': 'A'},
      {'type': 'text', 'body': 'B'},
    ]));
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('AE1: unknown block with fallback renders the fallback',
      (tester) async {
    await _pump(tester, _doc([
      {'type': 'mystery', 'fallback': {'type': 'text', 'body': 'FB'}},
    ]));
    expect(find.text('FB'), findsOneWidget);
  });

  testWidgets('AE2: unknown block without fallback is skipped, siblings render',
      (tester) async {
    await _pump(tester, _doc([
      {'type': 'mystery'},
      {'type': 'text', 'body': 'kept'},
    ]));
    expect(find.text('kept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AE3: all-unrenderable document falls back to the default doc',
      (tester) async {
    await _pump(
      tester,
      _doc([{'type': 'mystery'}]),
      defaultDoc: _doc([{'type': 'text', 'body': 'DEFAULT'}]),
    );
    expect(find.text('DEFAULT'), findsOneWidget);
  });

  testWidgets('AE6: unsatisfied requires renders the fallback', (tester) async {
    await _pump(tester, _doc([
      {
        'type': 'text',
        'body': 'V',
        'requires': {'video': '1.2'},
        'fallback': {'type': 'text', 'body': 'poster'},
      },
    ]));
    expect(find.text('poster'), findsOneWidget);
    expect(find.text('V'), findsNothing);
  });

  testWidgets('requires with an unparseable version fails closed to the fallback',
      (tester) async {
    // Capability present and high, but required version "v2" can't parse.
    // Pre-fix this fell open (need=0) and rendered 'V'; now it degrades.
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
                document: _doc([
                  {
                    'type': 'text',
                    'body': 'V',
                    'requires': {'video': 'v2'},
                    'fallback': {'type': 'text', 'body': 'poster'},
                  },
                ]),
                theme: NeoSduiTheme.fallback(),
                registry: _testRegistry(),
                capabilities: const {'video': 5},
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('poster'), findsOneWidget);
    expect(find.text('V'), findsNothing);
  });

  testWidgets('a throwing builder does not crash the screen', (tester) async {
    await _pump(tester, _doc([
      {'type': 'boom'},
      {'type': 'text', 'body': 'after'},
    ]));
    expect(find.text('after'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap dispatches the parsed action to onAction', (tester) async {
    NeoAction? got;
    await _pump(
      tester,
      _doc([{'type': 'cta', 'label': 'Go', 'action': 'https://neo.xyz'}]),
      onAction: (_, a) => got = a,
    );
    // Settle the entrance first. A block rises into place via a paint-only
    // transform, and a sliver hit tests its children against their *layout*
    // box — so mid-entrance the block's hit area lags its pixels. It lines back
    // up at rest, which is the only state a user can tap in.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    expect(got, isA<ExternalUrl>());
    expect((got as ExternalUrl).url.host, 'neo.xyz');
  });

  group('view rhythm and backdrop', () {
    final two = [
      {'type': 'text', 'body': 'A'},
      {'type': 'text', 'body': 'B'},
    ];
    double gap(WidgetTester t) =>
        t.getRect(find.text('B')).top - t.getRect(find.text('A')).bottom;

    testWidgets('default theme: padding and separators equal blockSpacing',
        (tester) async {
      final theme = NeoSduiTheme.fallback().copyWith(reduceMotion: true);
      await _pump(tester, _doc(two), theme: theme);
      expect(gap(tester), theme.blockSpacing);
      expect(tester.getRect(find.text('A')).top, theme.blockSpacing);
    });

    testWidgets('sectionSpacing separates top-level blocks only',
        (tester) async {
      final theme =
          NeoSduiTheme.fallback().copyWith(sectionSpacing: 36, blockSpacing: 20, reduceMotion: true);
      await _pump(tester, _doc(two), theme: theme);
      expect(gap(tester), 36);
      expect(tester.getRect(find.text('A')).top, 20);
    });

    testWidgets('sectionSpacing applies in the tabbed path, tab gaps stay',
        (tester) async {
      final theme = NeoSduiTheme.fallback()
          .copyWith(sectionSpacing: 36, blockSpacing: 20, reduceMotion: true);
      await _pump(
        tester,
        _doc([
          {'type': 'text', 'body': 'A'},
          {'type': 'text', 'body': 'B'},
          {
            'type': 'tabs',
            'tabs': [
              {
                'label': 'T',
                'blocks': [
                  {'type': 'text', 'body': 'X'},
                  {'type': 'text', 'body': 'Y'},
                ],
              },
            ],
          },
        ]),
        theme: theme,
        registry: defaultRegistry(),
      );
      await tester.pumpAndSettle();
      expect(gap(tester), 36);
      expect(
          tester.getRect(find.text('Y')).top - tester.getRect(find.text('X')).bottom,
          20);
    });

    for (final tabbed in [false, true]) {
      testWidgets('viewPadding top 4 / bottom 48 (tabbed: $tabbed)',
          (tester) async {
        final theme = NeoSduiTheme.fallback().copyWith(
            viewPadding: const EdgeInsets.only(top: 4, bottom: 48),
            reduceMotion: true);
        await _pump(
          tester,
          _doc([
            {'type': 'text', 'body': 'First'},
            if (tabbed)
              {
                'type': 'tabs',
                'tabs': [
                  {
                    'label': 'T',
                    'blocks': [
                      for (var i = 0; i < 80; i++)
                        {'type': 'text', 'body': 'z$i'},
                    ],
                  },
                ],
              }
            else
              for (var i = 0; i < 80; i++) {'type': 'text', 'body': 'z$i'},
            {'type': 'text', 'body': 'Last'},
          ]),
          theme: theme,
          registry: defaultRegistry(),
        );
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('First')).top, 4);
        final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
        for (var i = 0; i < 3; i++) {
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
        }
        expect(tester.getRect(find.text('Last')).bottom,
            tester.getRect(find.byType(Scrollable)).bottom - 48);
      });
    }

    testWidgets('backgroundOverlay adds a second decorated layer',
        (tester) async {
      int layers() => find
          .descendant(
              of: find.byType(NeoSduiView), matching: find.byType(DecoratedBox))
          .evaluate()
          .length;
      final grad = const LinearGradient(colors: [Color(0xFF000000), Color(0xFF111111)]);
      await _pump(tester, _doc(two),
          theme: NeoSduiTheme.fallback().copyWith(backgroundGradient: grad));
      final one = layers();
      await _pump(
          tester,
          _doc(two),
          theme: NeoSduiTheme.fallback().copyWith(
              backgroundGradient: grad,
              backgroundOverlay: (c) => const DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x33FF0000)))));
      expect(layers(), one + 1);
    });
  });
}
