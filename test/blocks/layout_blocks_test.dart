import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

final _theme = NeoSduiTheme.fallback();

Future<void> _pump(WidgetTester tester, Map<String, Object?> block) async {
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
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('row lays children side by side through the pipeline',
      (tester) async {
    await _pump(tester, {
      'type': 'row',
      'children': [
        {'type': 'text', 'body': 'left'},
        {'type': 'text', 'body': 'right'},
      ],
    });
    expect(find.byType(Row), findsOneWidget);
    final l = tester.getTopLeft(find.text('left')).dx;
    final r = tester.getTopLeft(find.text('right')).dx;
    expect(r, greaterThan(l)); // right sits to the right of left
  });

  testWidgets('column stacks children vertically', (tester) async {
    await _pump(tester, {
      'type': 'column',
      'children': [
        {'type': 'text', 'body': 'top'},
        {'type': 'text', 'body': 'bottom'},
      ],
    });
    final top = tester.getTopLeft(find.text('top')).dy;
    final bottom = tester.getTopLeft(find.text('bottom')).dy;
    expect(bottom, greaterThan(top));
  });

  testWidgets('group renders children inside a themed surface', (tester) async {
    await _pump(tester, {
      'type': 'group',
      'children': [
        {'type': 'text', 'body': 'inside'},
      ],
    });
    expect(find.text('inside'), findsOneWidget);
    final surfaces = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox));
    expect(
      surfaces.any((b) => (b.decoration as BoxDecoration).color == _theme.surface),
      isTrue,
    );
  });

  testWidgets('spacer sizes from the theme (blockSpacing * size)',
      (tester) async {
    await _pump(tester, {'type': 'spacer', 'size': 3});
    final sized = tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere(
        (s) => s.height == _theme.blockSpacing * 3,
        orElse: () => const SizedBox());
    expect(sized.height, _theme.blockSpacing * 3);
  });

  testWidgets('nested unknown child inside a container still skips safely',
      (tester) async {
    await _pump(tester, {
      'type': 'column',
      'children': [
        {'type': 'mystery'},
        {'type': 'text', 'body': 'kept'},
      ],
    });
    expect(find.text('kept'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
