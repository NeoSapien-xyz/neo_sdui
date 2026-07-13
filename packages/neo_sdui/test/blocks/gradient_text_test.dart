import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _grad = LinearGradient(colors: [Color(0xFF2DF790), Color(0xFF00F1A0)]);
final _plain = NeoSduiTheme.fallback(); // no accentGradient
final _gradTheme = NeoSduiTheme.fallback().copyWith(accentGradient: _grad);

Future<void> _pump(
  WidgetTester tester,
  Map<String, Object?> block,
  NeoSduiTheme theme,
) async {
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
              theme: theme,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('an accent heading paints the accent gradient when the theme sets one',
      (tester) async {
    await _pump(tester,
        {'type': 'header', 'title': 'NeoSapien', 'tone': 'accent'}, _gradTheme);
    expect(find.byType(ShaderMask), findsOneWidget); // whole-line gradient
    expect(find.text('NeoSapien'), findsOneWidget);
  });

  testWidgets('an accent heading with no gradient stays flat accent (golden-stable)',
      (tester) async {
    await _pump(tester,
        {'type': 'header', 'title': 'NeoSapien', 'tone': 'accent'}, _plain);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.widget<Text>(find.text('NeoSapien')).style!.color, _plain.accent);
  });

  testWidgets('plain non-accent text gets no gradient even under a gradient theme',
      (tester) async {
    await _pump(tester, {'type': 'text', 'body': 'plain copy'}, _gradTheme);
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('plain copy'), findsOneWidget);
  });

  testWidgets('an inline accent run gradients only that run (case B)', (tester) async {
    await _pump(tester, {
      'type': 'text',
      'body': [
        'Sign in with your ',
        {'text': 'NeoSapien', 'tone': 'accent'},
        ' account',
      ],
    }, _gradTheme);
    expect(find.byType(ShaderMask), findsOneWidget); // just the brand run
    expect(find.text('NeoSapien'), findsOneWidget); // the WidgetSpan child
    expect(tester.takeException(), isNull);
  });

  testWidgets('step numbers paint the accent gradient', (tester) async {
    await _pump(tester, {
      'type': 'steps',
      'items': [
        {'caption': 'One'},
        {'caption': 'Two'},
      ],
    }, _gradTheme);
    expect(find.byType(ShaderMask), findsNWidgets(2)); // the two numbers only
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a malformed run degrades without crashing', (tester) async {
    await _pump(tester, {
      'type': 'text',
      'body': [
        {'text': 42}, // bad run text -> '' (no throw at mount)
        'ok',
      ],
    }, _gradTheme);
    expect(tester.takeException(), isNull);
    expect(find.text('ok'), findsOneWidget);
  });
}
