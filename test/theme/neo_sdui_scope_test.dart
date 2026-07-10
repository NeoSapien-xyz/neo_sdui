import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

void main() {
  void noop(BuildContext context, NeoAction action) {}

  testWidgets('a descendant reads the theme via NeoSduiScope.of', (tester) async {
    final theme = NeoSduiTheme.fallback().copyWith(background: const Color(0xFF123456));
    late NeoSduiTheme read;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: NeoSduiScope(
          theme: theme,
          dispatch: noop,
          child: Builder(builder: (context) {
            read = NeoSduiScope.of(context).theme;
            return const SizedBox();
          }),
        ),
      ),
    );
    expect(read.background, const Color(0xFF123456));
  });

  testWidgets('updateShouldNotify fires only on a new theme instance', (tester) async {
    final a = NeoSduiTheme.fallback();
    final scope1 = NeoSduiScope(theme: a, dispatch: noop, child: const SizedBox());
    // Same instance -> no notify.
    expect(scope1.updateShouldNotify(scope1), isFalse);
    // New instance -> notify.
    final scope2 = NeoSduiScope(theme: a.copyWith(), dispatch: noop, child: const SizedBox());
    expect(scope2.updateShouldNotify(scope1), isTrue);
  });
}
