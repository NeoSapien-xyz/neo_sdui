import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Observation _color(String role, String hex, String page,
        [Provenance p = Provenance.variable]) =>
    Observation(
        roleKey: role,
        value: hex,
        page: page,
        provenance: p,
        kind: ValueKind.color);

void main() {
  test('single-look ledger emits one base, zero overrides', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(_color('surface', '0xFF202423', 'home')))
        .reconcile();
    final src = emitTheme(r);

    expect(src, contains('NeoSduiTheme.fallback().copyWith('));
    expect(src, contains('accent: Color(0xFF00F1A0),'));
    expect(src, isNot(contains('base.copyWith('))); // no divergent page
  });

  test('majority base + a single-field override for the outlier', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'a'))
          ..observe(_color('accent', '0xFF00F1A0', 'b'))
          ..observe(_color('accent', '0xFFFFC107', 'troubleshooting')))
        .reconcile();
    final src = emitTheme(r);

    // base is the majority (green); the outlier gets its own copyWith with
    // only the diverging field.
    expect(src, contains('accent: Color(0xFF00F1A0),'));
    expect(src, contains('final troubleshooting = base.copyWith('));
    expect(src, contains('accent: Color(0xFFFFC107),'));
  });

  test('inferred fields flag `// confirm:`; TODO stays outside the arg list', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(Observation(
              roleKey: 'title',
              value: 'TextStyle(fontSize: 22)',
              page: 'home',
              provenance: Provenance.inferred,
              kind: ValueKind.textStyle)))
        .reconcile();
    final src = emitTheme(r);

    expect(src, contains('title: TextStyle(fontSize: 22),  // confirm:'));
    // Any `// TODO(theme):` is a standalone comment line, never an argument —
    // guards the bare-TODO-won't-compile trap.
    for (final l in src.split('\n')) {
      if (l.contains('TODO(theme)')) {
        expect(l.trimLeft(), startsWith('// TODO(theme):'));
      }
    }
  });

  test('coverage report records the source per field', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(Observation(
              roleKey: 'title',
              value: 'TextStyle(fontSize: 22)',
              page: 'home',
              provenance: Provenance.inferred,
              kind: ValueKind.textStyle)))
        .reconcile();
    final report = coverageReport(r);

    expect(report, contains('variable: accent'));
    expect(report, contains('inferred: title'));
  });

  test('the in-process builder returns a live theme matching the ledger', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(_color('surface', '0xFF202423', 'home')))
        .reconcile();
    final theme = buildBaseTheme(r);

    expect(theme.accent, const Color(0xFF00F1A0));
    expect(theme.surface, const Color(0xFF202423));
    // an un-observed required role inherits fallback()
    expect(theme.onSurface, NeoSduiTheme.fallback().onSurface);
  });

  test('an unresolved conflict surfaces in the conflict list', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'a'))
          ..observe(_color('accent', '0xFFFFC107', 'b')))
        .reconcile();
    expect(r.conflictRoles, contains('accent'));
  });
}
