/// Terminal compile: turns a reconciled [RoleLedger] into a paste-in
/// `NeoSduiTheme` — one base plus a `copyWith` override per divergent page — a
/// live in-process theme for the render preview, and a coverage report.
///
/// The base emits as `NeoSduiTheme.fallback().copyWith(...)` so the 13 required
/// constructor params are always filled even when a role has no observation — a
/// bare `// TODO(theme):` can never stand in for a required argument, so the
/// emitted theme always compiles. Un-observed roles simply inherit `fallback()`
/// and are listed in the coverage report; `inferred` roles emit a `// confirm:`
/// marker and, unless waived, fail [inferredRoleGate].
///
/// The emitted source imports `flutter/widgets.dart`, `neo_sdui.dart`, and every
/// URI the ledger declares — a `GoogleFonts.workSans(...)` or `Icons.*` literal
/// compiles only if its package is imported, and an un-compilable theme is a
/// theme the app quietly replaces with the system font.
library;

import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';
import 'theme_ledger.dart';

/// How a live [NeoSduiTheme] absorbs one scalar role value.
typedef LiveApply = NeoSduiTheme Function(NeoSduiTheme base, String value);

/// One theme slot: its value [kind] and (for the colour/number roles the render
/// preview actually paints) how it lands on a live theme.
@immutable
class RoleSlot {
  const RoleSlot(this.kind, [this.live]) : isInt = false;

  /// A number slot whose theme field is `int`, not `double`.
  const RoleSlot.integer()
      : kind = ValueKind.number,
        live = null,
        isInt = true;
  final ValueKind kind;

  /// Only an integer literal may fill this slot (`2.0` would not compile).
  final bool isInt;

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
/// Unmodifiable — this is a single source of truth, not a per-consumer scratch
/// map (matches `kDefaultIcons` being `const`; the closures block `const` here,
/// so it is a runtime-frozen literal instead).
final Map<String, RoleSlot> kRoleSlots = Map.unmodifiable({
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
  'stepCardColor': RoleSlot(
      ValueKind.color, (t, v) => t.copyWith(stepCardColor: _color(v))),
  'stepCardBorderColor': RoleSlot(
      ValueKind.color, (t, v) => t.copyWith(stepCardBorderColor: _color(v))),
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
  'commandStyle': RoleSlot(ValueKind.textStyle),
  'calloutBody': RoleSlot(ValueKind.textStyle),
  'cardGradient': RoleSlot(ValueKind.gradient),
  'groupGradient': RoleSlot(ValueKind.gradient),
  'accentGradient': RoleSlot(ValueKind.gradient),
  'backgroundGradient': RoleSlot(ValueKind.gradient),
  'ctaGradient': RoleSlot(ValueKind.gradient),
  'titleGradient': RoleSlot(ValueKind.gradient),
  'radiusSm': RoleSlot(ValueKind.other),
  'radiusMd': RoleSlot(ValueKind.other),
  'radiusLg': RoleSlot(ValueKind.other),
  'contentPadding': RoleSlot(ValueKind.other),
  'cardPadding': RoleSlot(ValueKind.other),
  'cardShape': RoleSlot(ValueKind.other),
  'cardShadow': RoleSlot(ValueKind.other),
  'grainOverlay': RoleSlot(ValueKind.other),
  'motionDuration': RoleSlot(ValueKind.other),
  'motionCurve': RoleSlot(ValueKind.other),
  'swapDuration': RoleSlot(ValueKind.other),
  'entranceDuration': RoleSlot(ValueKind.other),
  'entranceCurve': RoleSlot(ValueKind.other),
  'reduceMotion': RoleSlot(ValueKind.other),
  // Component style fields — one slot per field, grouped into `<group>: <Class>(...)`
  // on emit (see kStyleGroups). No live painter: the preview keeps fallback.
  'tabs.trackColor': RoleSlot(ValueKind.color),
  'tabs.trackBorder': RoleSlot(ValueKind.other),
  'tabs.trackRadius': RoleSlot(ValueKind.other),
  'tabs.trackPadding': RoleSlot(ValueKind.other),
  'tabs.gap': RoleSlot(ValueKind.number),
  'tabs.neumorphic': RoleSlot(ValueKind.other),
  'tabs.pillColor': RoleSlot(ValueKind.color),
  'tabs.pillShadow': RoleSlot(ValueKind.other),
  'tabs.pillBorder': RoleSlot(ValueKind.other),
  'tabs.labelStyle': RoleSlot(ValueKind.textStyle),
  'tabs.unselectedWeight': RoleSlot(ValueKind.other),
  'tabs.labelPadding': RoleSlot(ValueKind.other),
  'tabs.unselectedColor': RoleSlot(ValueKind.color),
  'tabs.labelMaxLines': RoleSlot.integer(),
  'tabs.contentGap': RoleSlot(ValueKind.number),
  'card.thumbRadius': RoleSlot(ValueKind.other),
  'card.titleGap': RoleSlot(ValueKind.number),
  'card.actionGap': RoleSlot(ValueKind.number),
  'card.listSeparator': RoleSlot(ValueKind.other),
  'card.listIconColor': RoleSlot(ValueKind.color),
  'card.listIconGap': RoleSlot(ValueKind.number),
  'card.listCaret': RoleSlot(ValueKind.other),
  'card.listCaretGap': RoleSlot(ValueKind.number),
  'card.shadow': RoleSlot(ValueKind.other),
  'card.listShadow': RoleSlot(ValueKind.other),
  'card.pickerLineHeight': RoleSlot(ValueKind.number),
  'group.border': RoleSlot(ValueKind.other),
  'group.rowInset': RoleSlot(ValueKind.number),
  'group.padding': RoleSlot(ValueKind.number),
  'group.gap': RoleSlot(ValueKind.number),
  'steps.chipGap': RoleSlot(ValueKind.number),
  'steps.chipBorder': RoleSlot(ValueKind.color),
  'steps.badgeStyle': RoleSlot(ValueKind.textStyle),
  'steps.chipLabelStyle': RoleSlot(ValueKind.textStyle),
  'steps.cardShadow': RoleSlot(ValueKind.other),
  'steps.cardGap': RoleSlot(ValueKind.number),
  'steps.imageBackdrop': RoleSlot(ValueKind.color),
  'steps.labelStyle': RoleSlot(ValueKind.textStyle),
  'steps.labelGap': RoleSlot(ValueKind.number),
  'steps.instructionStyle': RoleSlot(ValueKind.textStyle),
  'steps.labelNumberOffset': RoleSlot.integer(),
  'steps.labelSuffix': RoleSlot(ValueKind.other),
  'steps.autoLinkUrls': RoleSlot(ValueKind.other),
  'callout.fill': RoleSlot(ValueKind.color),
  'callout.toneSurfaces': RoleSlot(ValueKind.other),
  'callout.border': RoleSlot(ValueKind.other),
  'callout.toneBorders': RoleSlot(ValueKind.other),
  'callout.radius': RoleSlot(ValueKind.other),
  'callout.padding': RoleSlot(ValueKind.other),
  'callout.emphasizeFirstBullet': RoleSlot(ValueKind.other),
  'faq.itemDecoration': RoleSlot(ValueKind.other),
  'faq.itemGap': RoleSlot(ValueKind.number),
  'faq.questionPadding': RoleSlot(ValueKind.other),
  'faq.caretGlyph': RoleSlot(ValueKind.other),
  'faq.openTurns': RoleSlot(ValueKind.number),
  'faq.caretColor': RoleSlot(ValueKind.color),
  'faq.answerStyle': RoleSlot(ValueKind.textStyle),
  'faq.answerPadding': RoleSlot(ValueKind.other),
  'header.subtitleGap': RoleSlot(ValueKind.number),
  'header.compactIconSize': RoleSlot(ValueKind.number),
  'header.compactIconGap': RoleSlot(ValueKind.number),
  'header.subheadingGap': RoleSlot(ValueKind.number),
  'header.subheadingTopInset': RoleSlot(ValueKind.number),
  'header.compactLineHeight': RoleSlot(ValueKind.number),
  'header.compactSubtitleGap': RoleSlot(ValueKind.number),
  'accordion.chevron': RoleSlot(ValueKind.other),
  'accordion.chevronSize': RoleSlot(ValueKind.number),
  'accordion.headPadding': RoleSlot(ValueKind.other),
  'accordion.headGap': RoleSlot(ValueKind.number),
  'accordion.bodyPadding': RoleSlot(ValueKind.other),
  'linkRow.border': RoleSlot(ValueKind.color),
  'linkRow.fill': RoleSlot(ValueKind.color),
  'linkRow.iconColor': RoleSlot(ValueKind.color),
  'linkRow.linkStyle': RoleSlot(ValueKind.textStyle),
  'linkRow.topPadding': RoleSlot(ValueKind.number),
  'linkRow.gap': RoleSlot(ValueKind.number),
  'linkRow.copySize': RoleSlot(ValueKind.number),
  'linkRow.copyGlyph': RoleSlot(ValueKind.other),
  'linkRow.checkGlyph': RoleSlot(ValueKind.other),
  'sectionSpacing': RoleSlot(ValueKind.number),
  'viewPadding': RoleSlot(ValueKind.other),
  'rowTitle': RoleSlot(ValueKind.textStyle),
  'panelTitle': RoleSlot(ValueKind.textStyle),
  'paragraph': RoleSlot(ValueKind.textStyle),
  'footnote': RoleSlot(ValueKind.textStyle),
  'subheading': RoleSlot(ValueKind.textStyle),
  'backgroundOverlay': RoleSlot(ValueKind.other),
});

/// Style-group prefix -> style class. A ledger key `tabs.gap` is one field of the
/// `tabs` group; the emit gathers a group's keys into one `tabs: NeoTabsStyle(...)`
/// argument, so each field keeps its own kind, provenance and source in the
/// ledger. The group names are `NeoSduiTheme` params.
const Map<String, String> kStyleGroups = {
  'tabs': 'NeoTabsStyle',
  'card': 'NeoCardStyle',
  'group': 'NeoGroupStyle',
  'steps': 'NeoStepsStyle',
  'callout': 'NeoCalloutStyle',
  'faq': 'NeoFaqStyle',
  'header': 'NeoHeaderStyle',
  'accordion': 'NeoAccordionStyle',
  'linkRow': 'NeoLinkRowStyle',
};

/// The style group a dotted role key belongs to (`tabs.gap` -> `tabs`), or null.
String? _styleGroupOf(String key) {
  final dot = key.indexOf('.');
  if (dot < 0) return null;
  final group = key.substring(0, dot);
  return kStyleGroups.containsKey(group) ? group : null;
}

/// The [NeoSduiTheme] fields [kRoleSlots] deliberately has no slot for, each with
/// its reason. Every *other* constructor param must be a registered slot:
/// `role_slots_complete_test` holds this pair against the constructor itself, so
/// a field added to the theme can never again reach the compile as a passive
/// `// TODO(theme): unsupported role` — which is exactly how `titleGradient`
/// shipped as a field two blocks read and the compile could not place.
const String _styleGroupReason = 'style group — observed per field as '
    '`<group>.<field>`, grouped into one style constructor call by kStyleGroups, '
    'never as a whole-object slot.';

const Map<String, String> kRoleSlotsIntentionallyAbsent = {
  'tabs': _styleGroupReason,
  'card': _styleGroupReason,
  'group': _styleGroupReason,
  'steps': _styleGroupReason,
  'callout': _styleGroupReason,
  'faq': _styleGroupReason,
  'header': _styleGroupReason,
  'accordion': _styleGroupReason,
  'linkRow': _styleGroupReason,
  'accents': 'map-typed — observed per entry as `accents.<name>`, matched by '
      '$kAccentsPrefix in _isKnownRole/_emitRoles, never as a whole-map slot.',
  'icons': 'map-typed — observed per entry as `icons.<name>`, matched by '
      '$kIconsPrefix (and spread over kDefaultIcons on emit).',
  'glyphs': 'map-typed — observed per entry as `glyphs.<name>`, a verbatim '
      'NeoGlyphBuilder literal, matched by $kGlyphsPrefix (no default to spread).',
};

/// A roleKey the compile knows how to place: a registered scalar slot or a
/// map-typed `accents.*` / `icons.*` entry. Everything else is unsupported.
bool _isKnownRole(String key) =>
    kRoleSlots.containsKey(key) ||
    key.startsWith(kAccentsPrefix) ||
    key.startsWith(kIconsPrefix) ||
    key.startsWith(kGlyphsPrefix);

/// A live [NeoSduiTheme] from a reconciled ledger, for U4's render preview.
///
/// Folds the reconciled base through [kRoleSlots], painting the colour/number
/// roles and the `accents.*` hues the preview needs. `textStyle`/`gradient`
/// roles and `icons.*` glyphs stay at `fallback()`: their ledger values are Dart
/// literals (`TextStyle(...)`, `Icons.download`) with no runtime constructor from
/// a string, so only the emitted paste-in source carries them — the structural
/// preview is palette-fidelity, not full-fidelity, by design (Dart has no `eval`).
/// A role whose ledger kind disagrees with its registry slot is left at fallback
/// too, so the preview never paints a garbage value the emit would reject.
NeoSduiTheme buildBaseTheme(Reconciled r) {
  var theme = NeoSduiTheme.fallback();
  final accents = <String, NeoAccent>{};
  r.base.forEach((key, role) {
    final slot = kRoleSlots[key];
    final live = slot?.live;
    if (live != null) {
      // Trust the registry's kind, not the ledger's self-declared one: a
      // kind-mismatched value (e.g. a `number` for a `color` slot) is skipped
      // rather than fed to the painter, matching emitTheme's skip.
      if (role.kind == slot!.kind) theme = live(theme, role.value);
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

/// The two imports every emitted theme needs; a ledger-declared import that
/// repeats one is dropped rather than emitted twice.
const List<String> _fixedImports = [
  'package:flutter/widgets.dart',
  'package:neo_sdui/neo_sdui.dart',
];

/// The lint suppressions an emitted theme needs: the literals are written the
/// way the ledger records them, not the way the analyzer would prefer.
const String _ignoreForFile = '// ignore_for_file: prefer_const_constructors, '
    'avoid_redundant_argument_values';

const String _checksumTag = '// checksum: fnv1a64:';

/// The Dart source for a theme: a [name]d theme (default `base`) plus a named
/// `copyWith` per divergent page. Always starts from
/// `NeoSduiTheme.fallback().copyWith(...)`.
///
/// The output is meant to be written straight into the app (`NEO_THEME_OUT`),
/// so it opens with a comment header carrying a checksum of everything after
/// it. [themeChecksumMatches] reads that back, which lets the app hold the
/// file against hand edits without the ledger being present.
String emitTheme(Reconciled r, {String name = 'base'}) {
  final body = _emitBody(r, name);
  return '// Generated by figwire theme-compile — review every `confirm` and '
      '`todo` marker before shipping.\n'
      '// Do not edit by hand: change the theme ledger and recompile.\n'
      '$_checksumTag${_fnv1a64(body)}\n'
      '$_ignoreForFile\n'
      '$body';
}

/// Whether [source]'s header checksum matches the code under it. False when
/// the file was edited by hand after the compile, or carries no checksum.
bool themeChecksumMatches(String source) {
  final lines = source.split('\n');
  var bodyStart = 0;
  String? recorded;
  while (bodyStart < lines.length && lines[bodyStart].startsWith('//')) {
    final line = lines[bodyStart];
    if (line.startsWith(_checksumTag)) {
      recorded = line.substring(_checksumTag.length).trim();
    }
    bodyStart++;
  }
  if (recorded == null) return false;
  return recorded == _fnv1a64(lines.skip(bodyStart).join('\n'));
}

/// Null when [actual] is exactly [expected]; otherwise a short summary naming
/// the first line that differs, for the compile tool's check mode.
String? themeSourceDrift({required String expected, required String actual}) {
  if (expected == actual) return null;
  final e = expected.split('\n'), a = actual.split('\n');
  var i = 0;
  while (i < e.length && i < a.length && e[i] == a[i]) {
    i++;
  }
  String at(List<String> l) => i < l.length ? l[i] : '<end of file>';
  return 'theme file differs from a fresh compile at line ${i + 1}:\n'
      '  compile: ${at(e)}\n'
      '  file:    ${at(a)}\n'
      'Recompile from the ledger instead of editing the file.';
}

/// 64-bit FNV-1a over the UTF-8 bytes, as 16 hex digits. Enough to notice an
/// edit; not a security check.
String _fnv1a64(String s) {
  var hash = -3750763034362895579; // 0xcbf29ce484222325 as a signed 64-bit int
  for (final byte in utf8.encode(s)) {
    hash = (hash ^ byte) * 0x100000001b3;
  }
  // Two 32-bit halves: a negative int's toRadixString keeps the sign.
  String half(int v) => (v & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return half(hash >> 32) + half(hash);
}

String _emitBody(Reconciled r, String name) {
  final b = StringBuffer();
  // The fixed pair, then the ledger's own (deduped against them, sorted) — so a
  // ledger literal that names a symbol outside dart:core/widgets/neo_sdui
  // (`GoogleFonts.workSans`, `Icons.iosShare`, an app-owned grain overlay) is
  // reproducible from the ledger instead of hand-patched back in after every
  // recompile.
  final extra = (r.imports.toSet()..removeAll(_fixedImports)).toList()..sort();
  for (final uri in [..._fixedImports, ...extra]) {
    b.writeln("import '$uri';");
  }
  b
    ..writeln()
    ..writeln('final $name = NeoSduiTheme.fallback().copyWith(');
  final skipped = _emitRoles(b, r.base);
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
  if (skipped.isNotEmpty) {
    b.writeln('// TODO(theme): unresolved ${(skipped..sort()).join(', ')} '
        '— ledger kind/value did not match the registry slot; inheriting '
        'NeoSduiTheme.fallback().');
  }

  final pages = r.overridesByPage.keys.toList()..sort();
  final usedIdents = <String>{name}; // reserve the base variable name
  for (final page in pages) {
    b
      ..writeln()
      ..writeln('final ${_uniqueIdent(page, usedIdents)} = $name.copyWith(');
    final skippedOverride =
        _emitRoles(b, r.overridesByPage[page]!, isOverride: true, base: name);
    b.writeln(');');
    final styleKeys = r.overridesByPage[page]!.keys
        .where((k) => _styleGroupOf(k) != null)
        .toList()
      ..sort();
    final unknownStyleKeys =
        styleKeys.where((k) => !kRoleSlots.containsKey(k)).toList();
    styleKeys.removeWhere(unknownStyleKeys.contains);
    if (unknownStyleKeys.isNotEmpty) {
      b.writeln('// TODO(theme): unsupported role(s) '
          '${unknownStyleKeys.join(', ')} on override "$page" — not a '
          'NeoSduiTheme field; extend kRoleSlots or fix the ledger.');
    }
    if (styleKeys.isNotEmpty) {
      b.writeln('// TODO(theme): unsupported role(s) ${styleKeys.join(', ')} '
          'on override "$page" — style classes have no copyWith; set them on '
          'the base theme.');
    }
    if (skippedOverride.isNotEmpty) {
      b.writeln('// TODO(theme): unresolved ${(skippedOverride..sort()).join(', ')} '
          'on override "$page" — ledger kind/value did not match the registry '
          'slot; inheriting the base value.');
    }
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
    ..write(line(Provenance.measured))
    ..write(line(Provenance.inferred))
    ..write(line(Provenance.todo));
  final keys = r.base.keys.toList()..sort();
  final sourced = [
    for (final k in keys)
      if (r.base[k]!.source != null) '  $k <- ${r.base[k]!.source}',
  ];
  final unsourced = [
    for (final k in keys)
      if (r.base[k]!.source == null) k,
  ];
  if (sourced.isNotEmpty) b.writeln('Sources:\n${sourced.join('\n')}');
  if (unsourced.isNotEmpty) b.writeln('Unsourced: ${unsourced.join(', ')}');
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

/// **The guess gate.** The blocking message when the compile would emit a role
/// whose value was `inferred` — read off a screenshot rather than out of the
/// design — or null when the theme is clean or [allow] waives it.
///
/// A slot that exists holding a fabricated number fails exactly as hard as a
/// missing slot, and no registry check can see it: the kind matches, the value
/// parses, the Dart compiles, and the screen is wrong. `provenance` is the only
/// field that knows, so the gate reads that. `// confirm:` markers stay on the
/// emitted source regardless — the gate blocks, the marker is the honesty record
/// for whoever waives it.
///
/// Only `inferred` fails. A `measured` role — read off the node's real
/// properties but not bound to a variable — is not a guess, and gating it would
/// make the gate unsatisfiable on any file whose tier caps variables (see
/// [Provenance]).
String? inferredRoleGate(Reconciled r, {required bool allow}) {
  final guessed = [
    for (final e in r.base.entries)
      if (e.value.provenance == Provenance.inferred) e.key,
    for (final page in r.overridesByPage.entries)
      for (final e in page.value.entries)
        if (e.value.provenance == Provenance.inferred) '${page.key}:${e.key}',
  ]..sort();
  if (guessed.isEmpty || allow) return null;
  return '${guessed.length} guessed role(s) — not read from the design:\n'
      '  ${guessed.join('\n  ')}\n'
      'Re-read each one and record what the design actually says: '
      'get_variable_defs for a bound token -> provenance:"variable"; '
      'get_design_context (type, fills, effects) for the node\'s own properties '
      '-> provenance:"measured". Most roles are "measured" — a file whose tier '
      'caps variables has almost none to bind, and that is not a defect. '
      'NEO_THEME_ALLOW_INFERRED=1 ships the guesses as-is — it silences the '
      'gate, it does not fix the theme.';
}

// --- emit helpers -----------------------------------------------------------

/// Emit `accents`/`icons` map roles are grouped; simple roles emit one arg line.
/// `copyWith` replaces the whole `accents`/`icons` map, so an override spreads the
/// base's map (`...base.accents`) and the base's `icons` spreads the defaults —
/// otherwise a page that diverges on one accent silently drops base's other
/// accents, and an emitted `icons` block would replace `kDefaultIcons` while
/// `role_lint` still assumes the defaults are present.
/// Emits `roles` and returns the simple scalar keys it deliberately skipped
/// (kind/value could not be vouched for) so the caller can flag them; `todo`
/// roles are also skipped but reported separately via [_uncovered].
List<String> _emitRoles(StringBuffer b, Map<String, ResolvedRole> roles,
    {bool isOverride = false, String base = 'base'}) {
  final accents = <String, ResolvedRole>{};
  final icons = <String, ResolvedRole>{};
  final glyphs = <String, ResolvedRole>{};
  final styles = <String, List<String>>{};
  final simple = <String>[];
  for (final key in roles.keys) {
    final styleGroup = _styleGroupOf(key);
    if (styleGroup != null) {
      // Style fields group into one constructor call on the base; an override
      // has no copyWith for them, so the caller flags them instead.
      if (!isOverride && kRoleSlots.containsKey(key)) {
        (styles[styleGroup] ??= <String>[]).add(key);
      }
      continue;
    }
    final accentName = stripRolePrefix(key, kAccentsPrefix);
    final iconName = stripRolePrefix(key, kIconsPrefix);
    final glyphName = stripRolePrefix(key, kGlyphsPrefix);
    if (accentName != null) {
      accents[accentName] = roles[key]!;
    } else if (iconName != null) {
      icons[iconName] = roles[key]!;
    } else if (glyphName != null) {
      glyphs[glyphName] = roles[key]!;
    } else if (kRoleSlots.containsKey(key)) {
      simple.add(key); // unknown scalar roles are skipped — emitTheme TODOs them
    }
  }
  simple.sort();
  final skipped = <String>[];
  for (final key in simple) {
    final role = roles[key]!;
    // `todo` means Figma could not answer: the field inherits fallback() and is
    // listed under the `// TODO(theme): no data` line, so it is never an arg.
    if (role.provenance == Provenance.todo) continue;
    // Emit only a value the registry can vouch for: the ledger's kind must match
    // the registry slot, and a color/number value must actually parse. Anything
    // else would print invalid or type-mismatched Dart (e.g. `radiusMd: 16` into
    // a BorderRadius field), so skip it and let the caller flag it instead.
    final expr = _scalarExpr(kRoleSlots[key]!, role);
    if (expr == null) {
      skipped.add(key);
      continue;
    }
    final confirm =
        role.provenance == Provenance.inferred ? '  // confirm:' : '';
    b.writeln('  $key: $expr,$confirm');
  }
  for (final group in kStyleGroups.keys) {
    final keys = styles[group];
    if (keys == null) continue;
    final lines = <String>[];
    for (final key in keys..sort()) {
      final role = roles[key]!;
      if (role.provenance == Provenance.todo) continue;
      final expr = _scalarExpr(kRoleSlots[key]!, role);
      if (expr == null) {
        skipped.add(key);
        continue;
      }
      final confirm =
          role.provenance == Provenance.inferred ? '  // confirm:' : '';
      lines.add('    ${key.substring(group.length + 1)}: $expr,$confirm');
    }
    if (lines.isEmpty) continue;
    b.writeln('  $group: ${kStyleGroups[group]}(');
    lines.forEach(b.writeln);
    b.writeln('  ),');
  }
  if (accents.isNotEmpty) {
    b.writeln('  accents: {');
    if (isOverride) b.writeln('    ...$base.accents,');
    for (final name in accents.keys.toList()..sort()) {
      b.writeln("    '$name': ${_accentExpr(accents[name]!)},");
    }
    b.writeln('  },');
  }
  if (icons.isNotEmpty) {
    b.writeln('  icons: {');
    b.writeln(isOverride ? '    ...$base.icons,' : '    ...kDefaultIcons,');
    for (final name in icons.keys.toList()..sort()) {
      b.writeln("    '$name': ${_expr(icons[name]!)},");
    }
    b.writeln('  },');
  }
  // Only a builder literal (`other`) can be a glyph; anything else is flagged.
  final glyphLines = <String>[];
  for (final name in glyphs.keys.toList()..sort()) {
    if (glyphs[name]!.kind != ValueKind.other) {
      skipped.add('$kGlyphsPrefix$name');
      continue;
    }
    glyphLines.add("    '$name': ${_expr(glyphs[name]!)},");
  }
  if (glyphLines.isNotEmpty) {
    b.writeln('  glyphs: {');
    if (isOverride) b.writeln('    ...$base.glyphs,');
    glyphLines.forEach(b.writeln);
    b.writeln('  },');
  }
  return skipped;
}

/// The Dart expression for a role value: colours/numbers are wrapped, everything
/// else (`TextStyle(...)`, `LinearGradient(...)`) is verbatim.
String _expr(ResolvedRole role) => switch (role.kind) {
      ValueKind.color => 'Color(${role.value})',
      ValueKind.number => role.value,
      _ => role.value,
    };

/// The Dart expression for a *known scalar* role, or null when the value can't be
/// vouched for. A known role's kind is the registry's, not the ledger's: a
/// kind mismatch returns null. A `color`/`number` whose value does not parse
/// returns null (it would print invalid Dart). `textStyle`/`gradient`/`other`
/// literals are emitted verbatim — the compile can't validate an arbitrary Dart
/// literal, so those still lean on the mandatory `flutter analyze <theme.dart>`
/// gate; the frequent color/number cases are caught here at the source.
String? _scalarExpr(RoleSlot slot, ResolvedRole role) {
  if (role.kind != slot.kind) return null;
  switch (slot.kind) {
    case ValueKind.color:
      return parseColorHex(role.value) == null ? null : 'Color(${role.value})';
    case ValueKind.number:
      final ok = slot.isInt
          ? int.tryParse(role.value) != null
          : double.tryParse(role.value) != null;
      return ok ? role.value : null;
    default:
      return role.value;
  }
}

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
