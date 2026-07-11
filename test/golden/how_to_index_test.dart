import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/how_to/how_to_screen.dart';
import '_harness.dart';

void main() {
  testWidgets('how_to index matches its golden', (tester) async {
    await pumpGuide(tester, HowToScreen.document());
    await expectLater(
      find.byType(NeoSduiView),
      matchesGoldenFile('goldens/how_to_index.png'),
    );
  });
}
