import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp_screen.dart';
import '../../example/mcp_theme.dart';
import '_harness.dart';

void main() {
  // Claude is the representative per-client view — the richest (3 tabs:
  // Web / Desktop App / Code). The golden captures the default-selected tab
  // (Web), proving the `tabs` block renders its selected child (KTD9).
  testWidgets('mcp client "claude" matches its golden', (tester) async {
    final doc = subDoc(McpScreen.document(), 'claude');
    await pumpGuide(tester, doc, theme: mcpTheme, height: 2400);
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/mcp_client_claude.png'),
    );
  });
}
