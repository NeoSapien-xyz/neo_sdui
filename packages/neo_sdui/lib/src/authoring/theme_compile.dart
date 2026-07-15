/// Terminal compile: turns a reconciled [RoleLedger] into a paste-in
/// `NeoSduiTheme` — one base plus a `copyWith` override per divergent page — a
/// live in-process theme for the render preview, and a coverage report.
///
/// The base emits as `NeoSduiTheme.fallback().copyWith(...)` so the 13 required
/// constructor params are always filled even when a role has no observation — a
/// bare `// TODO(theme):` can never stand in for a required argument, so the
/// emitted theme always compiles. Un-observed roles simply inherit `fallback()`
/// and are listed in the coverage report; `inferred` roles emit a `// confirm:`
/// marker.
library;

import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';
import 'theme_ledger.dart';

/// How a live [NeoSduiTheme] absorbs one scalar role value.
typedef LiveApply = NeoSduiTheme Function(NeoSduiTheme base, String value);

/// One theme slot: its value [kind] and (for the colour/number roles the render
/// preview actually paints) how it lands on a live theme.
@immutable
class RoleSlot {
  const RoleSlot(this.kind, [this.live]);
  final ValueKind kind;

  /// Applies this role to a live theme for the preview; null for the
  /// textStyle/gradient/other roles the structural preview leaves at fallback —
  /// their full literal still rides the emitted paste-in source.
  final LiveApply? live;
}

Color? _color(String v) {
  final n = parseColorHex(v);
  return n == null ? null : Color(n);
}

/// **The role registry** — the single source of truth (the DTCG / Style
/// Dictionary "token map" analog) for every scalar roleKey the compile supports.
/// [buildBaseTheme] applies the live-painted slots from here and [emitTheme]
/// validates every emitted role against these keys, so the live preview and the
/// paste-in source can never drift: add a theme field here **once** and both
/// sides pick it up (an unknown roleKey is flagged, never silently half-handled).
/// The map-typed slots (`accents.*`, `icons.*`) are keyed by prefix, not listed.
final Map<String, RoleSlot> kRoleSlots = {
  // Role colours — painted live.
  'accent': RoleSlot(ValueKind.color, (t, v) => t.copyWith(accent: _color(v))),
  'onAccent':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(onAccent: _color(v))),
  'surface':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(surface: _color(v))),
  'onSurface':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(onSurface: _color(v))),
  'danger': RoleSlot(ValueKind.color, (t, v) => t.copyWith(danger: _color(v))),
  'warning':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(warning: _color(v))),
  'background':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(background: _color(v))),
  'textPrimary':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(textPrimary: _color(v))),
  'textMuted':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(textMuted: _color(v))),
  'cardColor':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(cardColor: _color(v))),
  'gridLine':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(gridLine: _color(v))),
  'divider':
      RoleSlot(ValueKind.color, (t, v) => t.copyWith(divider: _color(v))),
  // Scales — painted live.
  'spaceSm': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(spaceSm: double.tryParse(v))),
  'spaceMd': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(spaceMd: double.tryParse(v))),
  'spaceLg': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(spaceLg: double.tryParse(v))),
  'blockSpacing': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(blockSpacing: double.tryParse(v))),
  'gridSpacing': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(gridSpacing: double.tryParse(v))),
  'backdropBlur': RoleSlot(
      ValueKind.number, (t, v) => t.copyWith(backdropBlur: double.tryParse(v))),
  // Type / gradient / shape roles — full literal rides the emitted source; the
  // structural preview keeps fallback (no live painter).
  'title': RoleSlot(ValueKind.textStyle),
  'subtitle': RoleSlot(ValueKind.textStyle),
  'body': RoleSlot(ValueKind.textStyle),
  'caption': RoleSlot(ValueKind.textStyle),
  'mono': RoleSlot(ValueKind.textStyle),
  'cardGradient': RoleSlot(ValueKind.gradient),
  'groupGradient': RoleSlot(ValueKind.gradient),
  'accentGradient': RoleSlot(ValueKind.gradient),
  'radiusSm': RoleSlot(ValueKind.other),
  'radiusMd': RoleSlot(ValueKind.other),
  'radiusLg': RoleSlot(ValueKind.other),
  'contentPadding': RoleSlot(ValueKind.other),
  'cardPadding': RoleSlot(ValueKind.other),
  'cardShape': RoleSlot(ValueKind.other),
  'cardShadow': RoleSlot(ValueKind.other),
  'motionDuration': RoleSlot(ValueKind.other),
  'motionCurve': RoleSlot(ValueKind.other),
  'reduceMotion': RoleSlot(ValueKind.other),
};

/// A roleKey the compile knows how to place: a registered scalar slot or a
/// map-typed `accents.*` / `icons.*` entry. Everything else is unsupported.
bool _isKnownRole(String key) =>
    kRoleSlots.containsKey(key) ||
    key.startsWith(kAccentsPrefix) ||
    key.startsWith(kIconsPrefix);

/// A live [NeoSduiTheme] from a reconciled ledger, for U4's render preview.
///
/// Folds the reconciled base through [kRoleSlots], painting the colour/number
/// roles the preview needs and leaving textStyle/gradient roles at `fallback()`
/// (the structural preview renders fonts as the default test font anyway, so
/// palette is what matters). The full-fidelity literals still ride the emitted
/// paste-in source; this builder exists so the render never has to `eval` it
/// (Dart has no runtime eval).
NeoSduiTheme buildBaseTheme(Reconciled r) {
  var theme = NeoSduiTheme.fallback();
  final accents = <String, NeoAccent>{};
  r.base.forEach((key, role) {
    final live = kRoleSlots[key]?.live;
    if (live != null) {
      theme = live(theme, role.value);
      return;
    }
    final accentName = stripRolePrefix(key, kAccentsPrefix);
    if (accentName != null && role.kind == ValueKind.color) {
      final c = _color(role.value);
      if (c != null) accents[accentName] = NeoAccent(c);
    }
  });
  return accents.isEmpty ? theme : theme.copyWith(accents: accents);
}

/// The paste-in Dart source: a `base` theme plus a named `copyWith` per divergent
/// page. Always starts from `NeoSduiTheme.fallback().copyWith(...)`.
String emitTheme(Reconciled r) {
  final b = StringBuffer()
    ..writeln('// Generated by figwire theme-compile — review every '
        '`confirm` and `todo` marker before shipping.')
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln("import 'package:neo_sdui/neo_sdui.dart';")
    ..writeln()
    ..writeln('final base = NeoSduiTheme.fallback().copyWith(');
  _emitRoles(b, r.base);
  b.writeln(');');

  final todo = _uncovered(r);
  if (todo.isNotEmpty) {
    b.writeln('// TODO(theme): no data for ${todo.join(', ')} '
        '— inheriting NeoSduiTheme.fallback().');
  }
  final unsupported = r.base.keys.where((k) => !_isKnownRole(k)).toList()..sort();
  if (unsupported.isNotEmpty) {
    b.writeln('// TODO(theme): unsupported role(s) ${unsupported.join(', ')} '
        '— not a NeoSduiTheme field; extend kRoleSlots or fix the ledger.');
  }

  final pages = r.overridesByPage.keys.toList()..sort();
  final usedIdents = <String>{'base'}; // reserve the base variable name
  for (final page in pages) {
    b
      ..writeln()
      ..writeln('final ${_uniqueIdent(page, usedIdents)} = base.copyWith(');
    _emitRoles(b, r.overridesByPage[page]!, isOverride: true);
    b.writeln(');');
  }
  return b.toString();
}

/// A human-readable per-field provenance report — not Dart, for sign-off.
String coverageReport(Reconciled r) {
  final byProv = <Provenance, List<String>>{};
  r.base.forEach((key, role) {
    (byProv[role.provenance] ??= <String>[]).add(key);
  });
  String line(Provenance p) {
    final list = byProv[p];
    if (list == null || list.isEmpty) return '';
    return '  ${p.name}: ${(list..sort()).join(', ')}\n';
  }

  final b = StringBuffer()
    ..writeln('Theme coverage — ${r.base.length} roles:')
    ..write(line(Provenance.variable))
    ..write(line(Provenance.inferred))
    ..write(line(Provenance.todo));
  if (r.conflictRoles.isNotEmpty) {
    b.writeln('Conflicts (base-vs-override): ${r.conflictRoles.join(', ')}');
  }
  if (r.overridesByPage.isNotEmpty) {
    final pages = r.overridesByPage.keys.toList()..sort();
    for (final p in pages) {
      final roles = r.overridesByPage[p]!.keys.toList()..sort();
      b.writeln('Override — $p: ${roles.join(', ')}');
    }
  }
  return b.toString();
}

// --- emit helpers -----------------------------------------------------------

/// Emit `accents`/`icons` map roles are grouped; simple roles emit one arg line.
/// `copyWith` replaces the whole `accents`/`icons` map, so an override spreads the
/// base's map (`...base.accents`) and the base's `icons` spreads the defaults —
/// otherwise a page that diverges on one accent silently drops base's other
/// accents, and an emitted `icons` block would replace `kDefaultIcons` while
/// `role_lint` still assumes the defaults are present.
void _emitRoles(StringBuffer b, Map<String, ResolvedRole> roles,
    {bool isOverride = false}) {
  final accents = <String, ResolvedRole>{};
  final icons = <String, ResolvedRole>{};
  final simple = <String>[];
  for (final key in roles.keys) {
    final accentName = stripRolePrefix(key, kAccentsPrefix);
    final iconName = stripRolePrefix(key, kIconsPrefix);
    if (accentName != null) {
      accents[accentName] = roles[key]!;
    } else if (iconName != null) {
      icons[iconName] = roles[key]!;
    } else if (kRoleSlots.containsKey(key)) {
      simple.add(key); // unknown scalar roles are skipped — emitTheme TODOs them
    }
  }
  simple.sort();
  for (final key in simple) {
    final role = roles[key]!;
    final confirm =
        role.provenance == Provenance.inferred ? '  // confirm:' : '';
    b.writeln('  $key: ${_expr(role)},$confirm');
  }
  if (accents.isNotEmpty) {
    b.writeln('  accents: {');
    if (isOverride) b.writeln('    ...base.accents,');
    for (final name in accents.keys.toList()..sort()) {
      b.writeln("    '$name': ${_accentExpr(accents[name]!)},");
    }
    b.writeln('  },');
  }
  if (icons.isNotEmpty) {
    b.writeln('  icons: {');
    b.writeln(isOverride ? '    ...base.icons,' : '    ...kDefaultIcons,');
    for (final name in icons.keys.toList()..sort()) {
      b.writeln("    '$name': ${_expr(icons[name]!)},");
    }
    b.writeln('  },');
  }
}

/// The Dart expression for a role value: colours/numbers are wrapped, everything
/// else (`TextStyle(...)`, `LinearGradient(...)`) is verbatim.
String _expr(ResolvedRole role) => switch (role.kind) {
      ValueKind.color => 'Color(${role.value})',
      ValueKind.number => role.value,
      _ => role.value,
    };

/// An `accents` map value is typed `NeoAccent`: wrap a bare colour, else the
/// value is already a `NeoAccent(...)` literal.
String _accentExpr(ResolvedRole role) => role.kind == ValueKind.color
    ? 'NeoAccent(Color(${role.value}))'
    : role.value;

/// Dart reserved words that cannot be a variable name (would break `final X =`).
const Set<String> _dartReserved = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with', //
};

/// A page's override variable name: sanitize, guard reserved words, and dedupe
/// against names already emitted (including the `base` variable) so two pages
/// that sanitize alike don't produce duplicate `final` declarations.
String _uniqueIdent(String page, Set<String> used) {
  var id = _ident(page);
  if (_dartReserved.contains(id)) id = '${id}_';
  var unique = id;
  var n = 2;
  while (!used.add(unique)) {
    unique = '$id$n';
    n++;
  }
  return unique;
}

String _ident(String page) {
  final cleaned = page.replaceAll(RegExp(r'[^A-Za-z0-9]'), ' ').trim();
  if (cleaned.isEmpty) return 'page';
  final parts = cleaned.split(RegExp(r'\s+'));
  final head = parts.first.toLowerCase();
  final tail = parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1));
  final ident = '${head[0].toLowerCase()}${head.substring(1)}${tail.join()}';
  return RegExp(r'^[0-9]').hasMatch(ident) ? 'p$ident' : ident;
}

/// Base roles Figma could not answer (provenance `todo`).
List<String> _uncovered(Reconciled r) {
  final out = [
    for (final e in r.base.entries)
      if (e.value.provenance == Provenance.todo) e.key,
  ]..sort();
  return out;
}
