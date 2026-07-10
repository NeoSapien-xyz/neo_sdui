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

  testWidgets('text uses body slot; variant subtitle uses subtitle slot',
      (tester) async {
    await _pump(tester, {'type': 'text', 'body': 'B'});
    expect(tester.widget<Text>(find.text('B')).style, _theme.body);
    await _pump(tester, {'type': 'text', 'body': 'M', 'variant': 'subtitle'});
    expect(tester.widget<Text>(find.text('M')).style, _theme.subtitle);
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
}
