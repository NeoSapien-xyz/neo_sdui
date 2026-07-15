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

  test('a named accent emits NeoAccent(Color(...)), not a bare Color', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accents.brand',
              value: '0xFF7A5CFF',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.color)))
        .reconcile();
    final src = emitTheme(r);
    // copyWith's `accents` is Map<String, NeoAccent> — a bare Color won't compile.
    expect(src, contains("'brand': NeoAccent(Color(0xFF7A5CFF)),"));
  });

  test('override page names sanitize to safe, unique, non-reserved idents', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'main'))
          ..observe(_color('accent', '0xFF00F1A0', 'main')) // majority base
          ..observe(_color('accent', '0xFF111111', 'base')) // clashes with base var
          ..observe(_color('accent', '0xFF222222', 'class')) // Dart reserved word
          ..observe(_color('accent', '0xFF333333', 'Home Page'))
          ..observe(_color('accent', '0xFF444444', 'home-page'))) // ident collision
        .reconcile();
    final src = emitTheme(r);

    // never redefine the base variable, never a reserved word
    expect(src, isNot(contains('final base = base.copyWith')));
    expect(src, isNot(contains('final class = base.copyWith')));
    // colliding page names get a numeric suffix
    expect(src, contains('final homePage = base.copyWith'));
    expect(src, contains('final homePage2 = base.copyWith'));
  });

  test('an override spreads base.accents so it does not drop siblings', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accents.brand',
              value: '0xFF7A5CFF',
              page: 'a',
              provenance: Provenance.variable,
              kind: ValueKind.color))
          ..observe(const Observation(
              roleKey: 'accents.brand',
              value: '0xFFFFC107',
              page: 'b',
              provenance: Provenance.variable,
              kind: ValueKind.color)))
        .reconcile();
    final src = emitTheme(r);
    expect(src, contains('...base.accents,'));
  });

  test('an inferred override keeps its `// confirm:` marker', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'a'))
          ..observe(_color('accent', '0xFF00F1A0', 'b'))
          ..observe(_color('accent', '0xFFFFC107', 'odd', Provenance.inferred)))
        .reconcile();
    final src = emitTheme(r);
    expect(src, contains('final odd = base.copyWith('));
    expect(src, contains('accent: Color(0xFFFFC107),  // confirm:'));
  });

  test('an unsupported roleKey is flagged, never emitted as a bad copyWith arg',
      () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(const Observation(
              roleKey: 'bogusField', // not a NeoSduiTheme field
              value: '0xFF111111',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.color)))
        .reconcile();
    final src = emitTheme(r);
    // would be `bogusField: Color(...)` — invalid Dart — under the old generic
    // emit; now it is skipped and reported instead.
    expect(src, isNot(contains('bogusField:')));
    expect(src, contains('// TODO(theme): unsupported role(s) bogusField'));
  });

  test('buildBaseTheme paints a number role straight from the registry', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'spaceLg',
              value: '40',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.number)))
        .reconcile();
    // the single-source registry drives the live build — no hand-kept field
    // list to drift from what emitTheme writes.
    expect(buildBaseTheme(r).spaceLg, 40);
  });

  test('a role whose ledger kind disagrees with its registry slot is skipped', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          // radiusMd is a registry `other` slot; a number value would emit
          // `radiusMd: 16` into a BorderRadius field — must be skipped instead.
          ..observe(const Observation(
              roleKey: 'radiusMd',
              value: '16',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.number)))
        .reconcile();
    final src = emitTheme(r);
    expect(src, isNot(contains('radiusMd:')));
    expect(src, contains('// TODO(theme): unresolved radiusMd'));
  });

  test('a color role with an unparseable value is skipped, not emitted as bad Dart',
      () {
    final r =
        (RoleLedger()..observe(_color('accent', 'nothex', 'home'))).reconcile();
    final src = emitTheme(r);
    expect(src, isNot(contains('Color(nothex)')));
    expect(src, contains('// TODO(theme): unresolved accent'));
  });

  test('a todo-provenance role is never emitted as a copyWith arg', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accent',
              value: '0xFF00F1A0',
              page: 'home',
              provenance: Provenance.todo,
              kind: ValueKind.color)))
        .reconcile();
    final src = emitTheme(r);
    expect(src, isNot(contains('accent: Color(0xFF00F1A0)')));
    expect(src, contains('// TODO(theme): no data for accent'));
  });

  test('buildBaseTheme leaves a kind-mismatched role at fallback', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accent',
              value: '16',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.number)))
        .reconcile();
    // accent slot is color; a number value must not be painted onto the theme.
    expect(buildBaseTheme(r).accent, NeoSduiTheme.fallback().accent);
  });

  test('a todo-provenance role is flagged on a standalone TODO(theme) line', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accent',
              value: '0xFF00F1A0',
              page: 'home',
              provenance: Provenance.todo,
              kind: ValueKind.color)))
        .reconcile();
    final src = emitTheme(r);
    final todoLines =
        src.split('\n').where((l) => l.contains('TODO(theme)')).toList();
    expect(todoLines, isNotEmpty);
    expect(todoLines.every((l) => l.trimLeft().startsWith('// TODO(theme):')),
        isTrue);
  });
}
