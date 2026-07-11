import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

void main() {
  Widget stub(BuildContext context, BlockNode node) => const SizedBox();

  test('known type returns its builder, unknown returns null', () {
    final r = BlockRegistry.empty()..register('header', stub);
    expect(r.builderFor('header'), isNotNull);
    expect(r.contains('header'), isTrue);
    expect(r.builderFor('nope'), isNull);
  });

  test('copy isolates registrations (add-on extends without touching core)', () {
    final core = BlockRegistry.empty()..register('header', stub);
    final extended = core.copy()..register('videoCard', stub);
    expect(extended.contains('videoCard'), isTrue);
    expect(core.contains('videoCard'), isFalse, reason: 'core must be untouched');
  });

  test('re-registering a type overrides it (last wins)', () {
    Widget other(BuildContext c, BlockNode n) => const Text('x');
    final r = BlockRegistry.empty()
      ..register('cta', stub)
      ..register('cta', other);
    expect(r.builderFor('cta'), same(other));
  });
}
