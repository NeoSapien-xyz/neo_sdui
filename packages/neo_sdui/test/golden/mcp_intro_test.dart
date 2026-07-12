import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp_screen.dart';
import '../../example/mcp_theme.dart';
import '_harness.dart';

void main() {
  testWidgets('mcp intro matches its golden', (tester) async {
    // The intro is the document's root blocks: hero, steps, client picker,
    // use-cases, footer nav. Tall — size the viewport to its full content.
    await pumpGuide(tester, McpScreen.document(), theme: mcpTheme, height: 3600);
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/mcp_intro.png'),
    );
  });
}
