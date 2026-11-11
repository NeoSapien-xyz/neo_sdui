import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _shadow = [BoxShadow(color: Color(0xFF123456), blurRadius: 7)];
final _base = NeoSduiTheme.fallback().copyWith(cardShadow: _shadow);

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> blocks, {
  NeoSduiTheme? theme,
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
              document: NeoDocument.fromJson({'version': 1, 'blocks': blocks}),
              theme: theme ?? _base,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Map<String, Object?> _picker() => {
  'type': 'card',
  'title': 'Claude',
  'subtitle': 'Desktop',
  'thumb': 'https://example.invalid/a.png',
  'actionLabel': 'Open Guide',
  'action': 'navigate:/x',
};

Map<String, Object?> _row(String t) => {
  'type': 'card',
  'title': t,
  'action': 'navigate:/x',
};

List<List<BoxShadow>> _shapeShadows(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((d) => d.decoration)
    .whereType<ShapeDecoration>()
    .map((d) => d.shadows ?? const <BoxShadow>[])
    .toList();

double _gapBetween(WidgetTester tester, Finder a, Finder b) =>
    tester.getTopLeft(b).dy - tester.getBottomLeft(a).dy;

void main() {
  testWidgets('picker card keeps squircle, radiusMd thumb and 8/8 gaps', (
    tester,
  ) async {
    await _pump(tester, [_picker()]);
    expect(find.byType(ClipRRect), findsOneWidget);
    expect(
      tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
      _base.radiusMd,
    );
    expect(_gapBetween(tester, find.text('Claude'), find.text('Desktop')), 8);
    expect(
      tester.getTopLeft(find.text('Open Guide')).dx -
          tester.getTopRight(find.text('Desktop')).dx,
      greaterThanOrEqualTo(8),
    );
    expect(_shapeShadows(tester).single, _shadow);
  });

  testWidgets('card style sets picker thumb radius and gaps', (tester) async {
    final r = BorderRadius.circular(3);
    await _pump(tester, [
      _picker(),
    ], theme: _base.copyWith(card: NeoCardStyle(thumbRadius: r, titleGap: 2)));
    expect(tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius, r);
    expect(_gapBetween(tester, find.text('Claude'), find.text('Desktop')), 2);
  });

  testWidgets('card.shadow empties the picker shadow only', (tester) async {
    final theme = _base.copyWith(card: const NeoCardStyle(shadow: []));
    await _pump(tester, [_picker()], theme: theme);
    expect(_shapeShadows(tester).single, isEmpty);
    await _pump(tester, [
      {'type': 'card', 'title': 'Footer', 'action': 'navigate:/x'},
    ], theme: theme);
    expect(_shapeShadows(tester).single, _shadow);
  });

  testWidgets('listSeparator draws N-1 hairlines between list rows', (
    tester,
  ) async {
    const side = BorderSide(color: Color(0xFFABCDEF));
    await _pump(tester, [
      {
        'type': 'group',
        'variant': 'list',
        'children': [_row('a'), _row('b'), _row('c')],
      },
    ], theme: _base.copyWith(card: const NeoCardStyle(listSeparator: side)));
    final seps = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).border?.top == side,
    );
    expect(seps, findsNWidgets(2));
    expect(
      tester.getTopLeft(seps.first).dy,
      greaterThan(tester.getBottomLeft(find.text('a')).dy),
    );
  });

  testWidgets('listCaret replaces the text caret in a list row', (
    tester,
  ) async {
    await _pump(
      tester,
      [
        {
          'type': 'group',
          'variant': 'list',
          'children': [_row('a')],
        },
      ],
      theme: _base.copyWith(
        card: NeoCardStyle(
          listCaret: (s, c) => SizedBox(key: const Key('caret'), width: s),
        ),
      ),
    );
    expect(find.byKey(const Key('caret')), findsOneWidget);
    expect(find.text('›'), findsNothing);
  });

  testWidgets('group.border draws a 1px side and group.gap spaces rules', (
    tester,
  ) async {
    const side = BorderSide(color: Color(0xFF445566));
    await _pump(
      tester,
      [
        {
          'type': 'group',
          'children': [
            {'type': 'text', 'body': 'top'},
            {'type': 'spacer', 'variant': 'rule'},
            {'type': 'text', 'body': 'bottom'},
          ],
        },
      ],
      theme: _base.copyWith(group: const NeoGroupStyle(border: side, gap: 16)),
    );
    final deco = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .single;
    expect(deco.border, Border.fromBorderSide(side));
    final rule = find.byType(CustomPaint).last;
    expect(
      tester.getTopLeft(rule).dy - tester.getBottomLeft(find.text('top')).dy,
      16,
    );
    expect(
      tester.getTopLeft(find.text('bottom')).dy - tester.getBottomLeft(rule).dy,
      16,
    );
  });
}
