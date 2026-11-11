import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Observation _c(String role, String hex, String page,
        [Provenance p = Provenance.variable]) =>
    Observation(
        roleKey: role,
        value: hex,
        page: page,
        provenance: p,
        kind: ValueKind.color);

void main() {
  group('RoleLedger accumulation', () {
    test('records a never-seen role and a page\'s wire role-usage', () {
      final ledger = RoleLedger()
        ..observe(_c('accent', '0xFF00F1A0', 'home'))
        ..useRole('home', 'tone:brand');

      expect(ledger.observations, hasLength(1));
      expect(ledger.observations.single.provenance, Provenance.variable);
      expect(ledger.roleUsage['home'], contains('tone:brand'));

      final r = ledger.reconcile();
      expect(r.base['accent']!.value, '0xFF00F1A0');
      expect(r.usedRoles, contains('tone:brand'));
      expect(r.conflictRoles, isEmpty);
    });
  });

  group('RoleLedger.reconcile — batch clustering', () {
    test('clusters two within-threshold values to one base, no conflict', () {
      final r = (RoleLedger()
            ..observe(_c('accent', '0xFF00F1A0', 'a')) // green
            ..observe(_c('accent', '0xFF00F0A0', 'b'))) // near-dupe (dist 1)
          .reconcile();

      expect(r.conflictRoles, isEmpty);
      expect(r.overridesByPage, isEmpty);
      expect(r.base['accent']!.pageCount, 2);
    });

    test('records two past-threshold values as a conflict with an override', () {
      final r = (RoleLedger()
            ..observe(_c('accent', '0xFF00F1A0', 'base1'))
            ..observe(_c('accent', '0xFF00F1A0', 'base2'))
            ..observe(_c('accent', '0xFFFFC107', 'odd'))) // amber, far
          .reconcile();

      expect(r.conflictRoles, ['accent']);
      expect(r.base['accent']!.value, '0xFF00F1A0'); // majority (2 pages)
      expect(r.base['accent']!.pageCount, 2);
      expect(r.overridesByPage['odd']!['accent']!.value, '0xFFFFC107');
      // the majority pages carry no override
      expect(r.overridesByPage.containsKey('base1'), isFalse);
    });

    test('an override carries the diverging cluster\'s provenance', () {
      final r = (RoleLedger()
            ..observe(_c('accent', '0xFF00F1A0', 'a'))
            ..observe(_c('accent', '0xFF00F1A0', 'b'))
            ..observe(_c('accent', '0xFFFFC107', 'odd', Provenance.inferred)))
          .reconcile();
      // provenance rides the override (not hardcoded to variable) so the
      // compile can still flag it `// confirm:`.
      expect(r.overridesByPage['odd']!['accent']!.provenance,
          Provenance.inferred);
    });

    test('basePage pins the base cluster over page-count majority (R8)', () {
      final feed = RoleLedger()
        ..observe(_c('accent', '0xFF00F1A0', 'a')) // majority green (2 pages)
        ..observe(_c('accent', '0xFF00F1A0', 'b'))
        ..observe(_c('accent', '0xFFFFC107', 'hero')); // minority amber, far

      final pinned = feed.reconcile(basePage: 'hero');
      expect(pinned.base['accent']!.value, '0xFFFFC107'); // pinned, not majority
      expect(pinned.overridesByPage['a']!['accent']!.value, '0xFF00F1A0');
      expect(pinned.overridesByPage['b']!['accent']!.value, '0xFF00F1A0');
      expect(pinned.overridesByPage.containsKey('hero'), isFalse);

      // an unknown basePage falls back to majority.
      expect(feed.reconcile(basePage: 'nope').base['accent']!.value,
          '0xFF00F1A0');
    });

    test('is feeding-order independent (guards batch-not-incremental, KTD6)', () {
      Reconciled run(List<(String, String)> feed) {
        final l = RoleLedger();
        for (final (hex, page) in feed) {
          l.observe(_c('accent', hex, page));
        }
        return l.reconcile();
      }

      final forward = run([('0xFF00F1A0', 'a'), ('0xFF00F0A0', 'b')]);
      final reverse = run([('0xFF00F0A0', 'b'), ('0xFF00F1A0', 'a')]);

      expect(forward.base['accent']!.value, reverse.base['accent']!.value);
      expect(forward.conflictRoles, reverse.conflictRoles);
    });

    test('threshold boundary resolves deterministically', () {
      // B channel exactly 24 apart -> within (<= 24) -> one cluster.
      final atCutoff = (RoleLedger()
            ..observe(_c('surface', '0xFF000000', 'a'))
            ..observe(_c('surface', '0xFF000018', 'b'))) // 0x18 = 24
          .reconcile();
      expect(atCutoff.conflictRoles, isEmpty);

      // 25 apart -> separate clusters -> conflict.
      final pastCutoff = (RoleLedger()
            ..observe(_c('surface', '0xFF000000', 'a'))
            ..observe(_c('surface', '0xFF000019', 'b'))) // 0x19 = 25
          .reconcile();
      expect(pastCutoff.conflictRoles, ['surface']);
    });

    test('reconcile keeps the best provenance in a cluster', () {
      final r = (RoleLedger()
            ..observe(_c('accent', '0xFF00F1A0', 'a', Provenance.inferred))
            ..observe(_c('accent', '0xFF00F0A0', 'b', Provenance.variable)))
          .reconcile();
      expect(r.base['accent']!.provenance, Provenance.variable);
    });
  });

  group('RoleLedger persistence', () {
    test('fresh clears; JSON round-trip preserves', () {
      final ledger = RoleLedger()
        ..observe(_c('accent', '0xFF00F1A0', 'home'))
        ..useRole('home', 'tone:brand');

      final restored =
          RoleLedger.fromJson(jsonDecode(jsonEncode(ledger.toJson())));
      expect(restored.observations, hasLength(1));
      expect(restored.observations.single.value, '0xFF00F1A0');
      expect(restored.roleUsage['home'], contains('tone:brand'));

      ledger.clear();
      expect(ledger.observations, isEmpty);
      expect(ledger.roleUsage, isEmpty);
    });

    test('fromJson skips a malformed observation instead of throwing', () {
      final ledger = RoleLedger.fromJson({
        'version': 1,
        'observations': [
          {
            'roleKey': 'accent',
            'value': '0xFF00F1A0',
            'page': 'home',
            'provenance': 'variable',
            'kind': 'color',
          },
          // bad enum name -> skipped, not thrown
          {
            'roleKey': 'surface',
            'value': '0xFF202423',
            'page': 'home',
            'provenance': 'variable',
            'kind': 'colour',
          },
          // missing field -> skipped
          {'roleKey': 'x', 'value': 'y', 'page': 'z', 'provenance': 'variable'},
        ],
        'roleUsage': <String, Object?>{},
      });
      expect(ledger.observations, hasLength(1));
      expect(ledger.observations.single.roleKey, 'accent');
    });

    test('fromJson counts dropped malformed observations', () {
      final ledger = RoleLedger.fromJson({
        'version': 1,
        'observations': [
          {
            'roleKey': 'accent',
            'value': '0xFF00F1A0',
            'page': 'home',
            'provenance': 'variable',
            'kind': 'color',
          },
          {
            'roleKey': 'surface',
            'value': '0xFF202423',
            'page': 'home',
            'provenance': 'variable',
            'kind': 'colour', // bad enum name
          },
          'not-a-map', // bad shape
        ],
        'roleUsage': <String, Object?>{},
      });
      // a corrupt/truncated write is visible, not swallowed as "no Figma data".
      expect(ledger.observations, hasLength(1));
      expect(ledger.malformedObservations, 2);
    });

    test('a clean load reports zero malformed observations', () {
      final restored = RoleLedger.fromJson(jsonDecode(jsonEncode(
          (RoleLedger()..observe(_c('accent', '0xFF00F1A0', 'home')))
              .toJson())));
      expect(restored.malformedObservations, 0);
    });

    test('an observation source round-trips, and stays optional', () {
      final ledger = RoleLedger()
        ..observe(const Observation(
            roleKey: 'accent',
            value: '0xFF00F1A0',
            page: 'home',
            provenance: Provenance.measured,
            kind: ValueKind.color,
            source: 'neo-mcp-guide@55caf81:css/styles.css:16'))
        ..observe(_c('surface', '0xFF202423', 'home'));
      final restored =
          RoleLedger.fromJson(jsonDecode(jsonEncode(ledger.toJson())));
      final byRole = {for (final o in restored.observations) o.roleKey: o};
      expect(byRole['accent']!.source,
          'neo-mcp-guide@55caf81:css/styles.css:16');
      expect(byRole['surface']!.source, isNull);
      expect(restored.malformedObservations, 0);
    });

    test('a non-string source makes the observation malformed', () {
      final ledger = RoleLedger.fromJson({
        'observations': [
          {
            'roleKey': 'accent',
            'value': '0xFF00F1A0',
            'page': 'home',
            'provenance': 'measured',
            'kind': 'color',
            'source': 16,
          },
        ],
      });
      expect(ledger.observations, isEmpty);
      expect(ledger.malformedObservations, 1);
    });

    test('fromJson tolerates malformed roleUsage shapes', () {
      final ledger = RoleLedger.fromJson({
        'version': 1,
        'observations': <Object?>[],
        'roleUsage': {
          'home': ['tone:accent', 42, 'icon:sparkle'], // non-string tag dropped
          7: ['tone:brand'], // non-string page dropped
          'about': 'not-a-list', // non-list tags dropped
        },
      });
      expect(ledger.roleUsage['home'], {'tone:accent', 'icon:sparkle'});
      expect(ledger.roleUsage.containsKey('about'), isFalse);
      expect(ledger.roleUsage, hasLength(1));
    });
  });
}
