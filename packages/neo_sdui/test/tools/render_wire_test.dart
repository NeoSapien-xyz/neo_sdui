import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// Renders an arbitrary wire JSON to a structural preview PNG for eyeballing.
///
/// Env-gated. Set `NEO_WIRE_JSON` to a wire `.json` path and run:
///
///   flutter test --update-goldens test/tools/render_wire_test.dart
///
/// to write `.render/preview.png`. Unset (the default — e.g. plain
/// `flutter test`), the test is skipped so the suite stays green.
///
/// Optionally set `NEO_THEME_LEDGER` to a role-ledger `.json` path to render the
/// wire under the **compiled** theme (built in-process from the ledger — Dart
/// has no runtime eval, so the render never touches the emitted `.dart` source).
/// Unset, it falls back to `NeoSduiTheme.fallback()`, byte-identical to before,
/// so a plain wire preview never churns the golden.
///
/// Structural only: runtime fonts render as the default test font and network
/// images as their error placeholder (KTD2) — enough for block presence, type,
/// order, and nesting, not pixel/font fidelity. Height adapts to content so a
/// tall page is not top-clipped.
void main() {
  final wirePath = Platform.environment['NEO_WIRE_JSON'];
  final ledgerPath = Platform.environment['NEO_THEME_LEDGER'];

  testWidgets('renders the wire JSON to a preview PNG', (tester) async {
    final json =
        jsonDecode(File(wirePath!).readAsStringSync()) as Map<String, Object?>;
    final doc = NeoDocument.fromJson(json);

    final theme = ledgerPath == null
        ? NeoSduiTheme.fallback()
        : buildBaseTheme(RoleLedger.fromJson(
                jsonDecode(File(ledgerPath).readAsStringSync())
                    as Map<String, Object?>)
            .reconcile());

    // Probe with a tiny viewport so content always overflows, read the scroll
    // extent to get the full content height, then re-pump at that height so a
    // tall page is captured whole rather than clipped to the top.
    await _pump(tester, doc, 100, theme);
    final scrollables = find.byType(Scrollable);
    var height = 3600.0;
    if (scrollables.evaluate().isNotEmpty) {
      final pos = tester.state<ScrollableState>(scrollables.first).position;
      height = (100 + pos.maxScrollExtent).clamp(200.0, 20000.0);
    }

    await _pump(tester, doc, height, theme);
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('../../.render/preview.png'),
    );
  }, skip: wirePath == null);
}

Future<void> _pump(
    WidgetTester tester, NeoDocument doc, double height, NeoSduiTheme theme) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 390,
            height: height,
            child: NeoSduiView(
              document: doc,
              theme: theme,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  tester.takeException(); // swallow deterministic network-image errors
}
