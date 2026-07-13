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
              theme: NeoSduiTheme.fallback(),
              registry: _testRegistry(),
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
    await tester.tap(find.text('Go'));
    expect(got, isA<ExternalUrl>());
    expect((got as ExternalUrl).url.host, 'neo.xyz');
  });
}
