import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui/src/blocks/_neumorphic.dart' show InsetShadowPainter;

Map<String, Object?> _tabs(List<String> labels) => {
  'type': 'tabs',
  'tabs': [
    for (final l in labels)
      {
        'label': l,
        'blocks': [
          {'type': 'text', 'body': 'body of $l'},
        ],
      },
  ],
};

/// [nested] puts the tabs inside a group, which renders the box form; top
/// level renders the pinned form.
Future<void> _pump(
  WidgetTester tester,
  NeoTabsStyle style, {
  List<String> labels = const ['One', 'Two', 'Three'],
  bool nested = false,
  double width = 400,
}) async {
  final block = nested
      ? {
          'type': 'group',
          'children': [_tabs(labels)],
        }
      : _tabs(labels);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: width,
            height: 800,
            child: NeoSduiView(
              document: NeoDocument.fromJson({
                'version': 1,
                'blocks': [block],
              }),
              theme: NeoSduiTheme.fallback().copyWith(
                tabs: style,
                reduceMotion: true,
              ),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _insetPainters = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is InsetShadowPainter,
);
final _divider = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints == BoxConstraints.tightFor(width: 1, height: 20),
);

Text _text(WidgetTester tester, String s) => tester.widget<Text>(find.text(s));

void main() {
  testWidgets(
    'default style: track + pill insets and a divider between unselected tabs',
    (tester) async {
      await _pump(tester, const NeoTabsStyle());
      final painters = tester
          .widgetList<CustomPaint>(_insetPainters)
          .map((p) => p.foregroundPainter! as InsetShadowPainter)
          .toList();
      expect(painters, hasLength(2)); // the track and the selected pill
      expect(painters.map((p) => p.insets.length), [2, 2]);
      expect(
        _divider,
        findsOneWidget,
      ); // between Two and Three; One is selected
    },
  );

  testWidgets(
    'neumorphic false drops insets and divider; trackBorder paints a Border',
    (tester) async {
      await _pump(
        tester,
        const NeoTabsStyle(
          neumorphic: false,
          trackBorder: BorderSide(color: Color(0xFF123456), width: 3),
        ),
      );
      expect(_insetPainters, findsNothing);
      expect(_divider, findsNothing);
      final bordered = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (d) =>
                d.decoration is BoxDecoration &&
                (d.decoration as BoxDecoration).border != null,
          );
      expect(bordered, hasLength(1));
      expect(
        (bordered.single.decoration as BoxDecoration).border,
        Border.all(color: const Color(0xFF123456), width: 3),
      );
    },
  );

  testWidgets('pillShadow paints outside the selected pill', (tester) async {
    const shadow = BoxShadow(color: Color(0xFF00FF00), blurRadius: 7);
    await _pump(
      tester,
      const NeoTabsStyle(neumorphic: false, pillShadow: [shadow]),
    );
    final shadowed = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where(
          (d) =>
              d.decoration is BoxDecoration &&
              (d.decoration as BoxDecoration).boxShadow != null,
        );
    expect(
      shadowed.single.decoration,
      isA<BoxDecoration>().having((d) => d.boxShadow, 'boxShadow', [shadow]),
    );
  });

  testWidgets(
    'unselectedColor and labelStyle apply to unselected labels only',
    (tester) async {
      final theme = NeoSduiTheme.fallback();
      const style = NeoTabsStyle(
        unselectedColor: Color(0xFFAA0000),
        labelStyle: TextStyle(fontSize: 11, letterSpacing: 1.5),
        unselectedWeight: FontWeight.w300,
      );
      await _pump(tester, style);
      final unselected = _text(tester, 'Two').style!;
      expect(unselected.color, const Color(0xFFAA0000));
      expect(unselected.fontSize, 11);
      expect(unselected.letterSpacing, 1.5);
      expect(unselected.fontWeight, FontWeight.w300);
      final selected = _text(tester, 'One').style!;
      expect(selected.color, theme.accent);
      expect(selected.fontWeight, FontWeight.w500);
      expect(selected.fontSize, 11);
    },
  );

  testWidgets('labelMaxLines 1 ellipsises a long label', (tester) async {
    await _pump(
      tester,
      const NeoTabsStyle(labelMaxLines: 1),
      labels: const ['A rather long tab label that cannot fit', 'Two'],
    );
    final t = _text(tester, 'A rather long tab label that cannot fit');
    expect(t.maxLines, 1);
    expect(t.overflow, TextOverflow.ellipsis);
    expect(_text(tester, 'Two').maxLines, 1);
  });

  testWidgets('contentGap sets the gap under the strip in the box form', (
    tester,
  ) async {
    await _pump(tester, const NeoTabsStyle(contentGap: 37), nested: true);
    expect(
      find.byWidgetPredicate((w) => w is SizedBox && w.height == 37),
      findsOneWidget,
    );
  });

  testWidgets('contentGap sets the gap under the strip in the pinned form', (
    tester,
  ) async {
    final theme = NeoSduiTheme.fallback();
    await _pump(tester, const NeoTabsStyle(contentGap: 37));
    final want =
        theme.contentPadding +
        EdgeInsets.only(top: 37, bottom: theme.blockSpacing);
    expect(
      find.byWidgetPredicate((w) => w is Padding && w.padding == want),
      findsOneWidget,
    );
  });
}
