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
Future<void> pumpGuide(WidgetTester tester, NeoDocument doc) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 390,
            height: 844,
            child: NeoSduiView(
              document: doc,
              theme: howToTheme,
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
