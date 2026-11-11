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

  test('the guess gate blocks an inferred role and names it', () {
    final r = (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'home'))
          ..observe(_color('surface', '0xFF202423', 'home', Provenance.inferred))
          ..observe(_color('accent', '0xFFFFC107', 'odd', Provenance.inferred)))
        .reconcile();
    final gate = inferredRoleGate(r, allow: false);

    // A guessed value sits in a real slot, parses, and compiles — provenance is
    // the only thing that knows it was read off a screenshot.
    expect(gate, isNotNull);
    expect(gate, contains('surface')); // base
    expect(gate, contains('odd:accent')); // the override, page-qualified
    expect(gate, contains('get_design_context'));
    expect(gate, isNot(contains('accent,'))); // the `variable` base is clean
  });

  test('the guess gate passes a variable-only ledger, and when waived', () {
    final clean = (RoleLedger()..observe(_color('accent', '0xFF00F1A0', 'home')))
        .reconcile();
    expect(inferredRoleGate(clean, allow: false), isNull);

    final guessed =
        (RoleLedger()..observe(_color('accent', '0xFF00F1A0', 'home',
                Provenance.inferred)))
            .reconcile();
    expect(inferredRoleGate(guessed, allow: true), isNull);
    // …but the honesty marker survives the waiver.
    expect(emitTheme(guessed), contains('// confirm:'));
  });

  test('ledger-declared imports emit after the fixed pair, deduped and sorted',
      () {
    final r = (RoleLedger(imports: [
      'package:neo_app/theme/card_grain_overlay.dart',
      'package:google_fonts/google_fonts.dart',
      'package:flutter/material.dart',
      'package:google_fonts/google_fonts.dart', // duplicate
      'package:flutter/widgets.dart', // already fixed
    ])..observe(_color('accent', '0xFF00F1A0', 'home')))
        .reconcile();
    final lines = emitTheme(r)
        .split('\n')
        .where((l) => l.startsWith('import '))
        .toList();

    // Without these the ledger's own literals (GoogleFonts.workSans, Icons.*,
    // an app-owned overlay) do not compile and the look degrades silently.
    expect(lines, [
      "import 'package:flutter/widgets.dart';",
      "import 'package:neo_sdui/neo_sdui.dart';",
      "import 'package:flutter/material.dart';",
      "import 'package:google_fonts/google_fonts.dart';",
      "import 'package:neo_app/theme/card_grain_overlay.dart';",
    ]);
  });

  test('a ledger round-trips its imports through JSON', () {
    final ledger = RoleLedger(imports: ['package:google_fonts/google_fonts.dart'])
      ..observe(_color('accent', '0xFF00F1A0', 'home'));
    final back = RoleLedger.fromJson(ledger.toJson());
    expect(back.imports, ['package:google_fonts/google_fonts.dart']);
    // a non-String entry is dropped, not thrown on — the ledger is read off disk
    expect(RoleLedger.fromJson({'imports': ['ok', 7]}).imports, ['ok']);
  });

  group('emitting straight into an app file', () {
    Reconciled twoPages() => (RoleLedger()
          ..observe(_color('accent', '0xFF00F1A0', 'a'))
          ..observe(_color('accent', '0xFF00F1A0', 'b'))
          ..observe(_color('accent', '0xFFFF0000', 'c')))
        .reconcile();

    test('a named emit declares that variable and overrides copy from it', () {
      final src = emitTheme(twoPages(), name: 'mcpGuideTheme');
      expect(src,
          contains('final mcpGuideTheme = NeoSduiTheme.fallback().copyWith('));
      expect(src, contains('= mcpGuideTheme.copyWith('));
      expect(src, isNot(contains('final base =')));
    });

    test('the default emit still declares base', () {
      expect(emitTheme(twoPages()),
          contains('final base = NeoSduiTheme.fallback().copyWith('));
    });

    test('the emit carries the lint suppressions the app file needs', () {
      expect(
          emitTheme(twoPages()).split('\n'),
          contains('// ignore_for_file: prefer_const_constructors, '
              'avoid_redundant_argument_values'));
    });

    test('a fresh emit verifies its own checksum', () {
      expect(themeChecksumMatches(emitTheme(twoPages())), isTrue);
    });

    test('a one-character edit to the body breaks the checksum', () {
      final src = emitTheme(twoPages());
      expect(themeChecksumMatches(src.replaceFirst('0xFF00F1A0', '0xFF00F1A1')),
          isFalse);
    });

    test('the checksum ignores the header comments themselves', () {
      final src = emitTheme(twoPages());
      final retitled = src.replaceFirst(
          RegExp(r'^// Generated[^\n]*'), '// Generated, reworded header');
      expect(retitled, isNot(src));
      expect(themeChecksumMatches(retitled), isTrue);
    });

    test('the checksum line is 16 lowercase hex digits', () {
      final line = emitTheme(twoPages())
          .split('\n')
          .firstWhere((l) => l.startsWith('// checksum:'));
      expect(line, matches(RegExp(r'^// checksum: fnv1a64:[0-9a-f]{16}$')));
    });

    test('a source with no checksum line does not verify', () {
      expect(themeChecksumMatches("import 'x.dart';\n"), isFalse);
    });

    test('drift check passes on an identical file and names the first change',
        () {
      final src = emitTheme(twoPages());
      expect(themeSourceDrift(expected: src, actual: src), isNull);
      final edited = src.replaceFirst('0xFF00F1A0', '0xFF00F1A1');
      final drift = themeSourceDrift(expected: src, actual: edited);
      expect(drift, isNotNull);
      expect(drift, contains('0xFF00F1A1'));
    });
  });

  test('the coverage report names each role\'s source and flags unsourced ones',
      () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'accent',
              value: '0xFF00F1A0',
              page: 'home',
              provenance: Provenance.measured,
              kind: ValueKind.color,
              source: 'neo-mcp-guide@55caf81:css/styles.css:16'))
          ..observe(_color('surface', '0xFF202423', 'home')))
        .reconcile();
    final report = coverageReport(r);
    expect(report, contains('accent <- neo-mcp-guide@55caf81:css/styles.css:16'));
    expect(report, contains('Unsourced: surface'));
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

  test('a glyphs.<name> observation emits inside a glyphs map', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'glyphs.help',
              value: '(s, c) => const SizedBox()',
              page: 'home',
              provenance: Provenance.measured,
              kind: ValueKind.other)))
        .reconcile();
    final src = emitTheme(r);
    expect(src, contains('glyphs: {'));
    expect(src, contains("'help': (s, c) => const SizedBox(),"));
    expect(src, isNot(contains('TODO(theme): unsupported role glyphs')));
  });

  group('component style groups', () {
    Observation obs(String role, String value, ValueKind kind,
            [String page = 'home']) =>
        Observation(
            roleKey: role,
            value: value,
            page: page,
            provenance: Provenance.measured,
            kind: kind);

    test('dotted keys group into one style constructor call', () {
      final r = (RoleLedger()
            ..observe(obs('tabs.trackColor', '0xE6101211', ValueKind.color))
            ..observe(obs('tabs.gap', '4', ValueKind.number)))
          .reconcile();
      final src = emitTheme(r);

      expect('NeoTabsStyle('.allMatches(src), hasLength(1));
      final start = src.indexOf('tabs: NeoTabsStyle(');
      final call = src.substring(start, src.indexOf('\n  ),', start));
      expect(call, contains('trackColor: Color(0xE6101211)'));
      expect(call, contains('gap: 4'));
      expect(src, isNot(contains('unsupported')));
    });

    test('a kind-mismatched dotted value is skipped and flagged', () {
      final r = (RoleLedger()
            ..observe(obs('tabs.gap', '0xFF000000', ValueKind.color)))
          .reconcile();
      final src = emitTheme(r);

      expect(src, isNot(contains('NeoTabsStyle(')));
      expect(src, contains('unresolved tabs.gap'));
    });

    test('a dotted key in a page override emits an unsupported TODO', () {
      final r = (RoleLedger()
            ..observe(obs('accent', '0xFF00F1A0', ValueKind.color, 'a'))
            ..observe(obs('accent', '0xFF00F1A0', ValueKind.color, 'b'))
            ..observe(obs('tabs.gap', '4', ValueKind.number, 'a'))
            ..observe(obs('tabs.gap', '4', ValueKind.number, 'b'))
            ..observe(obs('tabs.gap', '8', ValueKind.number, 'odd')))
          .reconcile();
      final src = emitTheme(r);

      final override = src.substring(src.indexOf('final odd = base.copyWith('));
      expect(override, isNot(contains('NeoTabsStyle(')));
      expect(override, contains('TODO(theme): unsupported'));
      expect(override, contains('tabs.gap'));
    });
  });
}
