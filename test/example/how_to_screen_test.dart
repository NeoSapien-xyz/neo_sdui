import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/how_to/how_to_screen.dart';
import '../../example/how_to/how_to_theme.dart';

void main() {
  // U9 Test Scenario: "a card tap opens its sheet view." Also the only coverage
  // of the generic OpenView(sheet) -> onPresentSheet dispatch path.
  testWidgets('tapping a how_to card presents its sheet view', (tester) async {
    Widget? presented;
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
                document: HowToScreen.document(),
                theme: howToTheme,
                onAction: (_, _) {},
                onPresentSheet: (_, view) => presented = view,
              ),
            ),
          ),
        ),
      ),
    );
    tester.takeException(); // deterministic network-image errors

    await tester.tap(find.text('How can I control Neo 1?'));
    await tester.pump();

    // The engine hands the app a sub-view (another NeoSduiView) to present.
    expect(presented, isA<NeoSduiView>());
  });
}
