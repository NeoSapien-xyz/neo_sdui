import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/how_to/how_to_theme.dart';

/// Pumps a guide document at a fixed size for golden capture.
///
/// Determinism (all a forward-regression golden needs — new render vs itself):
/// network images resolve to their error placeholder in the test binding, so no
/// HTTP stub is required; the theme's `Work Sans` family is unresolved so text
/// renders in the default test font. Both are stable across runs.
///
/// [theme] defaults to how_to's; the MCP goldens pass their own. [height] sizes
/// the viewport — the renderer scrolls, so a tall screen (the MCP guide) needs a
/// height that fits its full content, else the golden captures only the top.
Future<void> pumpGuide(
  WidgetTester tester,
  NeoDocument doc, {
  NeoSduiTheme? theme,
  double height = 844,
}) async {
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
              theme: theme ?? howToTheme,
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  tester.takeException(); // swallow the deterministic network-image errors
}

/// The sub-document the engine builds for a presented `screen`/`sheet` view: a
/// document over the view's blocks carrying the same `views` map so its actions
/// still resolve (mirrors how_to_sheet_test).
NeoDocument subDoc(NeoDocument doc, String viewId) {
  final view = doc.viewById(viewId)!;
  return NeoDocument(
    version: doc.version,
    blocks: view.blocks,
    views: doc.views,
  );
}
