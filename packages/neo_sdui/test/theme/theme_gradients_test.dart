import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// Pins the two client-owned gradient roles wired into the render:
/// [NeoSduiTheme.backgroundGradient] (screen backdrop) and
/// [NeoSduiTheme.ctaGradient] (a featured `emphasis:"high"` cta). Both follow
/// the `accentGradient`/`cardGradient` contract: null → flat, byte-identical.
/// Assertions target the specific widget (backdrop root / cta surface) so a
/// gradient painted on the wrong widget can't satisfy a whole-tree `contains`.
const _bgGrad = LinearGradient(
  colors: [Color(0xFF2B2B2B), Color(0xFF070707)],
  stops: [0.0, 0.7],
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
);
const _ctaGrad = LinearGradient(
  colors: [Color(0xFFB4F1D8), Color(0xFF00F1A0), Color(0xFF1CA175)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);

Future<void> _pump(
  WidgetTester tester,
  NeoSduiTheme theme, {
  Map<String, Object?>? block,
  List<Map<String, Object?>>? blocks,
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
              document: NeoDocument.fromJson(
                  {'version': 1, 'blocks': blocks ?? [block!]}),
              theme: theme,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// The gradient of a [Decoration], whether a plain [BoxDecoration] (rounded
/// shape) or a [ShapeDecoration] (squircle shape) — cta routes through both via
/// `shapeDecoration()`, so a helper that saw only BoxDecoration would blind the
/// squircle path.
Gradient? _gradientOf(Decoration d) => switch (d) {
      BoxDecoration(:final gradient) => gradient,
      ShapeDecoration(:final gradient) => gradient,
      _ => null,
    };

/// Every gradient painted by a DecoratedBox in the tree (gradient-less boxes
/// contribute null).
Iterable<Gradient?> _gradients(WidgetTester t) =>
    t.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((d) => _gradientOf(d.decoration));

/// The gradient on the **backdrop** specifically — the outermost DecoratedBox,
/// which is an ancestor of every block, so it is first in pre-order.
Gradient? _backdropGradient(WidgetTester t) =>
    _gradientOf(t.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration);

/// The gradient on the **cta surface** specifically — the DecoratedBox under
/// the cta's own GestureDetector, so a gradient that landed elsewhere can't
/// pass this off as the cta's fill.
Gradient? _ctaGradient(WidgetTester t) => _gradientOf(t
    .widget<DecoratedBox>(find
        .descendant(of: find.byType(GestureDetector), matching: find.byType(DecoratedBox))
        .first)
    .decoration);

void main() {
  testWidgets('backgroundGradient paints the backdrop (outermost DecoratedBox)',
      (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(backgroundGradient: _bgGrad);
    await _pump(tester, theme, block: {'type': 'text', 'body': 'x'});
    expect(_backdropGradient(tester), _bgGrad);
  });

  testWidgets('no backgroundGradient keeps the flat ColoredBox backdrop '
      '(byte-identical, no DecoratedBox at the root)', (tester) async {
    final theme = NeoSduiTheme.fallback(); // null backgroundGradient
    await _pump(tester, theme, block: {'type': 'text', 'body': 'x'});
    expect(
      tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color),
      contains(theme.background),
    );
    expect(_gradients(tester).whereType<Gradient>(), isEmpty);
  });

  testWidgets('ctaGradient fills a high-emphasis cta (on the cta surface)',
      (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(ctaGradient: _ctaGrad);
    await _pump(tester, theme, block: {
      'type': 'cta',
      'label': 'Contact Support',
      'action': 'https://neosapien.xyz',
      'emphasis': 'high',
    });
    expect(_ctaGradient(tester), _ctaGrad);
  });

  testWidgets('ctaGradient also fills a squircle high-emphasis cta '
      '(ShapeDecoration path)', (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(ctaGradient: _ctaGrad);
    await _pump(tester, theme, block: {
      'type': 'cta',
      'label': 'x',
      'action': 'https://neosapien.xyz',
      'emphasis': 'high',
      'shape': 'squircle',
    });
    // squircle routes through ShapeDecoration, which _gradientOf also reads.
    expect(_ctaGradient(tester), _ctaGrad);
  });

  testWidgets('a normal-emphasis cta ignores ctaGradient (flat fill)',
      (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(ctaGradient: _ctaGrad);
    await _pump(tester, theme,
        block: {'type': 'cta', 'label': 'x', 'action': 'https://neosapien.xyz'});
    expect(_ctaGradient(tester), isNull);
  });

  testWidgets('high-emphasis cta with no ctaGradient stays flat accent '
      '(byte-identical)', (tester) async {
    final theme = NeoSduiTheme.fallback(); // null ctaGradient
    await _pump(tester, theme, block: {
      'type': 'cta',
      'label': 'x',
      'action': 'https://neosapien.xyz',
      'emphasis': 'high',
    });
    expect(_ctaGradient(tester), isNull);
  });

  testWidgets('background and cta gradients route to their own widgets, '
      'not each other', (tester) async {
    final theme = NeoSduiTheme.fallback()
        .copyWith(backgroundGradient: _bgGrad, ctaGradient: _ctaGrad);
    await _pump(tester, theme, blocks: [
      {'type': 'text', 'body': 'x'},
      {'type': 'cta', 'label': 'x', 'action': 'https://neosapien.xyz', 'emphasis': 'high'},
    ]);
    // Distinct values: a cross-wiring bug (cta painting the bg gradient, or the
    // reverse) drops one of these, since neither widget would carry both.
    expect(_backdropGradient(tester), _bgGrad);
    expect(_ctaGradient(tester), _ctaGrad);
  });
}
