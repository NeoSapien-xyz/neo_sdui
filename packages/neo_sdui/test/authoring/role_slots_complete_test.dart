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
    expect(kRoleSlots.keys.where((k) => !params.contains(k)), isEmpty);
    expect(kRoleSlotsIntentionallyAbsent.keys.where((k) => !params.contains(k)),
        isEmpty);
    // An exemption with no reason is just an ignore list.
    expect(kRoleSlotsIntentionallyAbsent.values.where((r) => r.trim().isEmpty),
        isEmpty);
  });
}
