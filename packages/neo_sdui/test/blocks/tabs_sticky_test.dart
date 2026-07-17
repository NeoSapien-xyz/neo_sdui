import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// A tabs block with [webSteps] blocks in its first tab — enough content to
/// outrun the viewport so scrolling is observable.
NeoDocument _doc({int webSteps = 40}) => NeoDocument.fromJson({
      'version': 1,
      'blocks': [
        {
          'type': 'tabs',
          'tabs': [
            {
              'label': 'Web',
              'blocks': [
                for (var i = 0; i < webSteps; i++)
                  {'type': 'text', 'body': 'web step $i'},
              ],
            },
            {
              'label': 'Desktop',
              'blocks': [
                {'type': 'text', 'body': 'desktop steps'},
              ],
            },
          ],
        },
      ],
    });

Future<void> _pump(WidgetTester tester, {int webSteps = 40}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 400,
            height: 800,
            child: NeoSduiView(
              document: _doc(webSteps: webSteps),
              theme: NeoSduiTheme.fallback().copyWith(reduceMotion: true),
              onAction: (_, _) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drags the list up by [by], grabbing content rather than the strip so the
/// gesture can't land as a tab tap.
Future<void> _scroll(WidgetTester tester, String grab, double by) async {
  await tester.drag(find.text(grab), Offset(0, -by));
  await tester.pump();
}

double _stripTop(WidgetTester tester) => tester.getRect(find.text('Web')).top;

void main() {
  // A top-level tabs block pins its strip: a floating segmented pill that stays
  // under the app bar while the tab content scrolls past beneath it (a real
  // SliverPersistentHeader, not a scroll-with-content strip). These guard the
  // pinning + the shared selection.
  testWidgets('the strip pins under the app bar as content scrolls',
      (tester) async {
    await _pump(tester);
    final atRest = _stripTop(tester);

    await _scroll(tester, 'web step 8', 150);
    // Floating, it would have ridden the 150px drag up (well past atRest - 100);
    // pinned, it holds at the top, moving up only by the small top padding.
    expect(_stripTop(tester), greaterThan(atRest - 40),
        reason: 'strip should pin near the top, not scroll away');
  });

  testWidgets('tapping a tab switches its content', (tester) async {
    await _pump(tester);
    expect(find.text('desktop steps'), findsNothing);

    await tester.tap(find.text('Desktop'));
    await tester.pumpAndSettle();
    expect(find.text('desktop steps'), findsOneWidget);
  });
}
