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
      expect(r.overridesByPage['odd']!['accent'], '0xFFFFC107');
      // the majority pages carry no override
      expect(r.overridesByPage.containsKey('base1'), isFalse);
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
  });
}
