import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

// Top-level function builders so `same()` identity checks are reliable
// (Dart canonicalizes top-level tear-offs).
Widget _mediaA(BuildContext c, BlockNode n) => const SizedBox();
Widget _mediaEnhance(BuildContext c, BlockNode n) => const SizedBox();
Widget _chartA(BuildContext c, BlockNode n) => const SizedBox();
Widget _chartB(BuildContext c, BlockNode n) => const SizedBox();
Widget _video(BuildContext c, BlockNode n) => const SizedBox();

void main() {
  test('AE1: an add-on replacing a core type wins with no collision', () {
    final a = NeoSduiAddon(name: 'imageAddon', blocks: {'media': _mediaA});
    final c = NeoSdui.compose([a]);
    expect(c.registry.builderFor('media'), same(_mediaA));
    expect(c.report.typeCollisions, isEmpty);
  });

  test('AE2: two add-ons on the same new type -> last wins, collision reported', () {
    final a = NeoSduiAddon(name: 'chartA', blocks: {'chart': _chartA});
    final b = NeoSduiAddon(name: 'chartB', blocks: {'chart': _chartB});
    final c = NeoSdui.compose([a, b]);
    expect(c.registry.builderFor('chart'), same(_chartB));
    expect(c.report.typeCollisions, hasLength(1));
    final collision = c.report.typeCollisions.single;
    expect(collision.type, 'chart');
    expect(collision.winner, 'chartB');
    expect(collision.loser, 'chartA');
  });

  test('AE3: a new-type add-on derives its capability without host declaration', () {
    final v = NeoSduiAddon(
      name: 'videoAddon',
      blocks: {'video': _video},
      capabilities: {'video': 1},
    );
    final c = NeoSdui.compose([v]);
    expect(c.capabilities['video'], 1);
  });

  test('AE4: host overlay adds a capability alongside the derived ones', () {
    final v = NeoSduiAddon(
      name: 'videoAddon',
      blocks: {'video': _video},
      capabilities: {'video': 1},
    );
    final c = NeoSdui.compose([v], capabilities: {'deeplink': 2});
    expect(c.capabilities['deeplink'], 2);
    expect(c.capabilities['video'], 1);
    expect(c.report.overlayCollisions, isEmpty);
  });

  test('AE5: overlay does not override a derived capability; collision noted', () {
    final v = NeoSduiAddon(
      name: 'videoAddon',
      blocks: {'video': _video},
      capabilities: {'video': 2},
    );
    final c = NeoSdui.compose([v], capabilities: {'video': 1});
    expect(c.capabilities['video'], 2);
    expect(c.report.overlayCollisions, hasLength(1));
    final collision = c.report.overlayCollisions.single;
    expect(collision.capability, 'video');
    expect(collision.kept, 2);
    expect(collision.ignored, 1);
  });

  test('AE6: a capability with no new-type builder is orphaned, not derived', () {
    final x = NeoSduiAddon(name: 'addonX', capabilities: {'x': 1});
    final c = NeoSdui.compose([x]);
    expect(c.report.orphanedCapabilities.map((o) => o.capability), contains('x'));
    expect(c.capabilities.containsKey('x'), isFalse);
  });

  test('AE7: an empty list returns the core registry, empty caps, clean report', () {
    final c = NeoSdui.compose([]);
    expect(c.registry.contains('card'), isTrue);
    expect(c.registry.contains('media'), isTrue);
    expect(c.capabilities, isEmpty);
    expect(c.report.isClean, isTrue);
    expect(c.report.appliedOrder, isEmpty);
    expect(() => NeoSdui.compose([]), returnsNormally);
  });

  test('R12: compose never throws even with collisions + orphans (debug asserts on)', () {
    final a = NeoSduiAddon(name: 'a', blocks: {'chart': _chartA});
    final b = NeoSduiAddon(name: 'b', blocks: {'chart': _chartB});
    final orphan = NeoSduiAddon(name: 'orphan', capabilities: {'ghost': 1});
    expect(() => NeoSdui.compose([a, b, orphan]), returnsNormally);
    final c = NeoSdui.compose([a, b, orphan]);
    expect(c.report.typeCollisions, isNotEmpty);
    expect(c.report.orphanedCapabilities, isNotEmpty);
  });

  test('R9: applied order equals the add-on list order', () {
    final a = NeoSduiAddon(name: 'a', blocks: {'chart': _chartA});
    final b = NeoSduiAddon(name: 'b', blocks: {'chart': _chartB});
    final orphan = NeoSduiAddon(name: 'orphan', capabilities: {'ghost': 1});
    final c = NeoSdui.compose([a, b, orphan]);
    expect(c.report.appliedOrder, ['a', 'b', 'orphan']);
  });

  test('R10: a core-only override carries no capability and no collision', () {
    final enhancer = NeoSduiAddon(
      name: 'enhancer',
      blocks: {'media': _mediaEnhance},
      capabilities: {'enhance': 1},
    );
    final c = NeoSdui.compose([enhancer]);
    expect(c.registry.builderFor('media'), same(_mediaEnhance));
    expect(c.report.typeCollisions, isEmpty);
    expect(c.report.orphanedCapabilities.map((o) => o.capability),
        contains('enhance'));
    expect(c.capabilities.containsKey('enhance'), isFalse);
  });
}
