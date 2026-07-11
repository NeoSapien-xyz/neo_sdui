import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/how_to/how_to_screen.dart';
import '_harness.dart';

void main() {
  for (final id in ['control', 'lights', 'memory']) {
    testWidgets('how_to sheet "$id" matches its golden', (tester) async {
      final doc = HowToScreen.document();
      final view = doc.viewById(id)!;
      // What the engine builds for a presented sheet: a NeoSduiView over the
      // view's blocks, carrying the same `views` map so its actions resolve.
      final sheetDoc = NeoDocument(
        version: doc.version,
        blocks: view.blocks,
        views: doc.views,
      );
      await pumpGuide(tester, sheetDoc);
      await expectLater(
        find.byType(NeoSduiView),
        matchesGoldenFile('goldens/how_to_sheet_$id.png'),
      );
    });
  }
}
