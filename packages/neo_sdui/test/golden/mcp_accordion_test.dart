import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp_theme.dart';
import '_harness.dart';

void main() {
  final doc = NeoDocument.fromJson({
    'version': 1,
    'blocks': [
      {
        'type': 'accordion',
        'title': 'Advanced: manual setup',
        'children': [
          {'type': 'text', 'body': 'Add the server by hand if the one-click flow does not fit.'},
          {'type': 'code', 'content': 'claude mcp add neosapien'},
        ],
      },
      {
        'type': 'accordion',
        'title': 'Closed section',
        'children': [
          {'type': 'text', 'body': 'Hidden until opened.'},
        ],
      },
    ],
  });

  testWidgets('mcp accordion, one open and one closed, matches its golden',
      (tester) async {
    await pumpGuide(tester, doc, theme: mcpTheme, height: 500);
    await tester.tap(find.text('Advanced: manual setup'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/mcp_accordion.png'),
    );
  });
}
