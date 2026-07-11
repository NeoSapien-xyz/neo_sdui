import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp_screen.dart';
import '../../example/mcp_theme.dart';
import '_harness.dart';

void main() {
  testWidgets('mcp faq (first item expanded) matches its golden', (tester) async {
    await pumpGuide(tester, subDoc(McpScreen.document(), 'faq'),
        theme: mcpTheme, height: 1600);
    // faq open state is client-owned — expand the first item so the golden
    // reflects an answer, not just collapsed rows (plan U12 scenario).
    await tester.tap(find.text('What is NeoSapien MCP?'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/mcp_faq.png'),
    );
  });
}
