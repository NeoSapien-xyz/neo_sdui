import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp_screen.dart';
import '../../example/mcp_theme.dart';
import '_harness.dart';

void main() {
  testWidgets('mcp troubleshooting matches its golden', (tester) async {
    // header + five item callouts + "Still having issues?" + Contact Support cta.
    await pumpGuide(tester, subDoc(McpScreen.document(), 'troubleshooting'),
        theme: mcpTheme, height: 1600);
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/mcp_troubleshooting.png'),
    );
  });
}
