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

  testWidgets('an accentFlat run stays flat accent even when the theme sets a gradient',
      (tester) async {
    // The figma step-4 example prompt: the accent hue, painted solid — NOT the
    // darkening `accentGradient` that plain `tone:accent` would apply.
    await _pump(tester, {
      'type': 'text',
      'body': [
        'try: ',
        {'text': 'What do you know about me?', 'tone': 'accentFlat'},
      ],
    }, _gradTheme);
    expect(find.byType(ShaderMask), findsNothing); // flat, no gradient mask
  });

  testWidgets('a strong run reads the primary text color, not an accent hue',
      (tester) async {
    // The figma "Add those tasks to my Notion." clause: white, standing out from
    // the muted rest — NOT a green accent, and flat (no gradient mask).
    await _pump(tester, {
      'type': 'text',
      'body': [
        {'text': 'Add those tasks to my Notion.', 'tone': 'strong'},
        ' Your AI has both.',
      ],
    }, _gradTheme);
    expect(find.byType(ShaderMask), findsNothing);
    final text = tester.widget<Text>(find.byType(Text).first);
    final first = (text.textSpan! as TextSpan).children!.first as TextSpan;
    expect(first.style!.color, _gradTheme.textPrimary);
  });

  testWidgets('an inline mono run rides the mono slot and stays flat', (tester) async {
    // The figma Claude-Code caption: `claude mcp list` inline in grey IBM Plex
    // Mono, mid-sentence — not a boxed code chip, not accent text.
    await _pump(tester, {
      'type': 'text',
      'body': [
        'Run ',
        {'text': 'claude mcp list', 'mono': true},
        ' to verify.',
      ],
    }, _gradTheme);
    expect(find.byType(ShaderMask), findsNothing); // flat, no gradient mask
    final text = tester.widget<Text>(find.byType(Text).first);
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    final mono = spans.firstWhere((s) => s.text == 'claude mcp list');
    // Mono slot, not the body scale (mono is 13, body is 14 in the fallback).
    expect(mono.style!.fontSize, _gradTheme.mono.fontSize);
    expect(mono.style!.fontFamilyFallback, _gradTheme.mono.fontFamilyFallback);
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

  testWidgets('two accent hues coexist on one screen; an unmapped tone stays plain',
      (tester) async {
    const brandGrad = LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFFC400)]);
    final theme = NeoSduiTheme.fallback().copyWith(
      accentGradient: _grad,
      accents: const {'brand': NeoAccent(Color(0xFFFF8A00), brandGrad)},
    );
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
                    {'type': 'header', 'title': 'Accent', 'tone': 'accent'},
                    {'type': 'header', 'title': 'Brand', 'tone': 'brand'},
                    {'type': 'header', 'title': 'Ghost', 'tone': 'ghost'},
                  ],
                }),
                theme: theme,
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );
    // accent + brand each shade their own gradient; an unmapped tone is plain.
    expect(find.byType(ShaderMask), findsNWidgets(2));
    expect(tester.widget<Text>(find.text('Ghost')).style!.color, theme.title.color);
  });

  testWidgets('a steps tone recolors the number badges to a distinct hue',
      (tester) async {
    const brandGrad = LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFFC400)]);
    final theme = NeoSduiTheme.fallback().copyWith(
      accentGradient: _grad,
      accents: const {'brand': NeoAccent(Color(0xFFFF8A00), brandGrad)},
    );
    await _pump(tester, {
      'type': 'steps',
      'tone': 'brand',
      'items': [
        {'caption': 'One'},
        {'caption': 'Two'},
      ],
    }, theme);
    expect(find.byType(ShaderMask), findsNWidgets(2)); // both numbers, brand hue
    expect(find.text('1'), findsOneWidget);
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
