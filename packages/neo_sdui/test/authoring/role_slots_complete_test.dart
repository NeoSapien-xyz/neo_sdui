import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// A3 — `kRoleSlots` must not drift from the `NeoSduiTheme` it compiles into.
///
/// `titleGradient` shipped as a real theme field that `header.dart` and
/// `steps.dart` read, while `kRoleSlots` never learned about it: a ledger
/// observation for it compiled to a passive `// TODO(theme): unsupported role`
/// and the gradient silently vanished from the emitted theme. The app was
/// repaired by hand; the registry stayed broken, because nothing could see it.
/// This can.
///
/// Parses the constructor out of the source rather than reflecting over it —
/// `dart:mirrors` is unavailable under Flutter.

const _themeSource = 'lib/src/theme/neo_sdui_theme.dart';

/// The `this.<name>` params of the `const NeoSduiTheme({...})` constructor.
/// Deliberately dumb — one constructor, one regex, no Dart parser: it either
/// matches that param list or returns a set the guard test below rejects.
Set<String> _ctorParams(String src) {
  const open = 'const NeoSduiTheme({';
  final start = src.indexOf(open);
  final end = start < 0 ? -1 : src.indexOf('});', start);
  if (end < 0) return const {};
  return {
    for (final m in RegExp(r'this\.(\w+)').allMatches(src.substring(start, end)))
      m.group(1)!,
  };
}

const _stylesSource = 'lib/src/theme/neo_sdui_styles.dart';

/// The `this.<name>` params of `const <className>({...})` in [src].
Set<String> _styleParams(String src, String className) {
  final open = 'const $className({';
  final start = src.indexOf(open);
  final end = start < 0 ? -1 : src.indexOf('});', start);
  if (end < 0) return const {};
  return {
    for (final m in RegExp(r'this\.(\w+)').allMatches(src.substring(start, end)))
      m.group(1)!,
  };
}

/// The disagreements between style fields and slots, as `<group>.<param>` keys:
/// fields with no slot, and `<group>.*` slots with no field.
({List<String> unslotted, List<String> orphaned}) _styleDrift(
    Map<String, Set<String>> fieldsByGroup, Set<String> slotKeys) {
  final fields = {
    for (final g in fieldsByGroup.entries)
      for (final p in g.value) '${g.key}.$p',
  };
  final prefixes = fieldsByGroup.keys.map((g) => '$g.');
  return (
    unslotted: (fields.difference(slotKeys)).toList()..sort(),
    orphaned: [
      for (final k in slotKeys)
        if (prefixes.any(k.startsWith) && !fields.contains(k)) k,
    ]..sort(),
  );
}

void main() {
  final params = _ctorParams(File(_themeSource).readAsStringSync());

  test('the constructor parser matched the real param list', () {
    // The first param, the last param, and the field that proved the drift —
    // a rename that quietly empties the scan fails here instead of passing
    // every check below vacuously.
    expect(params, containsAll(<String>['accent', 'icons', 'titleGradient']));
  });

  test('every NeoSduiTheme field is a role slot or a reasoned exemption', () {
    final unslotted = params
        .where((p) =>
            !kRoleSlots.containsKey(p) &&
            !kRoleSlotsIntentionallyAbsent.containsKey(p))
        .toList()
      ..sort();
    expect(unslotted, isEmpty,
        reason: 'theme fields the compile cannot place: ${unslotted.join(', ')}'
            ' — register each in kRoleSlots (the emit and the live preview then'
            ' both pick it up) or add it to kRoleSlotsIntentionallyAbsent with'
            ' the reason it can never be observed.');
  });

  test('no slot or exemption outlives the field it names', () {
    // The other direction: a slot for a deleted field emits an argument that no
    // longer compiles, and a stale exemption hides a real gap.
    // Dotted `<group>.<field>` slots are held against the style classes below.
    expect(
        kRoleSlots.keys.where((k) => !k.contains('.') && !params.contains(k)),
        isEmpty);
    expect(kRoleSlotsIntentionallyAbsent.keys.where((k) => !params.contains(k)),
        isEmpty);
    // An exemption with no reason is just an ignore list.
    expect(kRoleSlotsIntentionallyAbsent.values.where((r) => r.trim().isEmpty),
        isEmpty);
  });

  group('component styles', () {
    final stylesSrc = File(_stylesSource).readAsStringSync();
    final Map<String, Set<String>> fieldsByGroup = {
      for (final e in kStyleGroups.entries)
        e.key: _styleParams(stylesSrc, e.value),
    };

    test('every style group is a theme param left out of the scalar slots', () {
      expect(kStyleGroups, isNotEmpty);
      for (final g in kStyleGroups.keys) {
        expect(params, contains(g));
        expect(kRoleSlotsIntentionallyAbsent, contains(g));
        expect(fieldsByGroup[g], isNotEmpty, reason: '$g parsed no fields');
      }
    });

    test('every style field has a `<group>.<param>` slot and back', () {
      final drift = _styleDrift(fieldsByGroup, kRoleSlots.keys.toSet());
      expect(drift.unslotted, isEmpty,
          reason: 'style fields with no slot: ${drift.unslotted.join(', ')}');
      expect(drift.orphaned, isEmpty,
          reason: 'slots with no style field: ${drift.orphaned.join(', ')}');
    });

    test('the drift check fails in both directions', () {
      final fields = {
        'tabs': {'gap'}
      };
      final noSlot = _styleDrift(fields, {});
      expect(noSlot.unslotted, ['tabs.gap']);
      final noField = _styleDrift(fields, {'tabs.gap', 'tabs.ghost'});
      expect(noField.orphaned, ['tabs.ghost']);
      expect(_styleDrift(fields, {'tabs.gap'}).unslotted, isEmpty);
    });
  });
}
