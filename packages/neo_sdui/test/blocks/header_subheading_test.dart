import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _sub = TextStyle(fontSize: 20, fontWeight: FontWeight.w500);

Map<String, Object?> _header() => {
  'type': 'header',
  'title': 'Quick setup',
  'subtitle': 'Two steps',
};

Map<String, Object?> _tabs(Map<String, Object?> block) => {
  'type': 'tabs',
  'tabs': [
    {
      'label': 'One',
      'blocks': [block],
    },
    {'label': 'Two', 'blocks': []},
  ],
};

Future<void> _pump(
  WidgetTester tester,
  Map<String, Object?> block, {
  TextStyle? subheading,
  NeoHeaderStyle header = const NeoHeaderStyle(),
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: SizedBox(
          width: 400,
          height: 800,
          child: NeoSduiView(
            document: NeoDocument.fromJson({
              'version': 1,
              'blocks': [block],
            }),
            theme: NeoSduiTheme.fallback().copyWith(
              subheading: subheading,
              header: header,
              reduceMotion: true,
            ),
            onAction: (_, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TextStyle? _style(WidgetTester t, String s) =>
    t.widget<Text>(find.text(s)).style;

void main() {
  testWidgets('a header in a tab renders at the theme subheading', (t) async {
    await _pump(t, _tabs(_header()), subheading: _sub);
    expect(_style(t, 'Quick setup'), _sub);
  });

  testWidgets('without a subheading it matches a top-level header', (t) async {
    await _pump(t, _tabs(_header()));
    final inTab = _style(t, 'Quick setup');
    await _pump(t, _header());
    expect(inTab, _style(t, 'Quick setup'));
  });

  testWidgets('a header in a group in a tab stays compact', (t) async {
    await _pump(
      t,
      _tabs({
        'type': 'group',
        'children': [_header()],
      }),
      subheading: _sub,
    );
    expect(_style(t, 'Quick setup'), isNot(_sub));
    expect(_style(t, 'Quick setup'), isNot(NeoSduiTheme.fallback().title));
  });

  testWidgets('the subtitle gap reads subheadingGap', (t) async {
    await _pump(
      t,
      _tabs(_header()),
      header: const NeoHeaderStyle(subtitleGap: 4, subheadingGap: 11),
    );
    final gap = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == 11,
    );
    expect(gap, findsOneWidget);
  });

  testWidgets('compact header line height and subtitle gap read the style', (
    t,
  ) async {
    await _pump(
      t,
      {
        'type': 'group',
        'children': [_header()],
      },
      header: const NeoHeaderStyle(
        subtitleGap: 6,
        compactSubtitleGap: 4,
        compactLineHeight: 1.1,
      ),
    );
    expect(_style(t, 'Quick setup')?.height, 1.1);
    final gap = find.byWidgetPredicate((w) => w is SizedBox && w.height == 4);
    expect(gap, findsOneWidget);
    await _pump(t, {
      'type': 'group',
      'children': [_header()],
    });
    expect(_style(t, 'Quick setup')?.height, isNull);
  });
}
