import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// U4: the render preview builds a live theme in-process from the ledger and
/// renders a wire under it without throwing. (The env-gated `render_wire_test`
/// tool is the golden path; this is the automated smoke.)
void main() {
  final doc = NeoDocument.fromJson(const {
    'version': 1,
    'blocks': [
      {'type': 'header', 'title': 'Hello'},
      {'type': 'text', 'body': 'body'},
    ],
  });

  Future<void> pump(WidgetTester tester, NeoSduiTheme theme) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: SizedBox(
          width: 390,
          height: 800,
          child: NeoSduiView(document: doc, theme: theme, onAction: (_, _) {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders under a ledger-built theme without throwing',
      (tester) async {
    final theme = buildBaseTheme((RoleLedger()
          ..observe(const Observation(
              roleKey: 'accent',
              value: '0xFF00F1A0',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.color))
          ..observe(const Observation(
              roleKey: 'surface',
              value: '0xFF202423',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.color)))
        .reconcile());

    await pump(tester, theme);
    expect(find.byType(NeoSduiView), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(theme.accent, const Color(0xFF00F1A0));
  });

  testWidgets('renders under the fallback theme (no ledger) without throwing',
      (tester) async {
    await pump(tester, NeoSduiTheme.fallback());
    expect(find.byType(NeoSduiView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
