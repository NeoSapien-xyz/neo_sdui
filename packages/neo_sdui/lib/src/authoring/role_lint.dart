/// Role-drift lint — the theme side of the wire's vocabulary gate. Every look
/// role the accumulated pages' wires named (`tone`/`icon`, recorded in the
/// ledger's role-usage registry) must resolve to a slot in the compiled theme,
/// or it renders flat. Also flags theme slots no wire uses (advisory).
///
/// Works on the reconciled ledger, not a live theme: a named accent resolves iff
/// the ledger declared `accents.<name>` (or it is the built-in `accent`/
/// `critical`); a named icon resolves iff `icons.<name>` was declared (or it is
/// one of the default glyphs, or a package-drawn glyph like `sparkle`).
/// `emphasis` always resolves (built-in fill), so it never drifts.
library;

import '../model/validate_vocabulary.dart' show WireIssueSeverity;
import '../theme/neo_sdui_theme.dart'
    show kDefaultIcons, kDrawnIcons, kBuiltinAccentTones;
import 'theme_ledger.dart';

/// One drift problem. Collected, never thrown. Reuses [WireIssueSeverity] so the
/// theme gate speaks the same block/warn vocabulary as `validateWireVocabulary`.
class RoleDriftIssue {
  const RoleDriftIssue(this.role, this.message, this.severity);

  final String role;
  final String message;
  final WireIssueSeverity severity;

  bool get isBlocking => severity == WireIssueSeverity.block;

  @override
  String toString() => '$role: $message [${isBlocking ? 'block' : 'warn'}]';
}

/// Check the compiled theme covers every wire role, and note unused theme slots.
List<RoleDriftIssue> lintRoleDrift(Reconciled r) {
  final out = <RoleDriftIssue>[];

  final namedAccents = <String>{
    for (final k in r.base.keys) ?stripRolePrefix(k, kAccentsPrefix),
  };
  final namedIcons = <String>{
    for (final k in r.base.keys) ?stripRolePrefix(k, kIconsPrefix),
  };
  final namedGlyphs = <String>{
    for (final k in r.base.keys) ?stripRolePrefix(k, kGlyphsPrefix),
  };
  final referencedAccents = <String>{};
  final referencedIcons = <String>{};

  for (final tag in r.usedRoles) {
    final i = tag.indexOf(':');
    if (i < 0) continue;
    final kind = tag.substring(0, i);
    final name = tag.substring(i + 1);
    switch (kind) {
      case 'tone':
        referencedAccents.add(name);
        if (!kBuiltinAccentTones.contains(name) && !namedAccents.contains(name)) {
          out.add(RoleDriftIssue(
              tag,
              "wire tone '$name' has no theme accent slot",
              WireIssueSeverity.block));
        }
      case 'icon':
        referencedIcons.add(name);
        if (!kDefaultIcons.containsKey(name) &&
            !kDrawnIcons.contains(name) &&
            !namedIcons.contains(name) &&
            !namedGlyphs.contains(name)) {
          out.add(RoleDriftIssue(
              tag,
              "wire icon '$name' has no theme icon slot",
              WireIssueSeverity.block));
        }
      // `emphasis:*` always resolves via the built-in fill; unknown kinds are
      // not look roles this theme owns — neither drifts.
    }
  }

  for (final a in namedAccents) {
    if (!referencedAccents.contains(a)) {
      out.add(RoleDriftIssue('accents.$a',
          'theme accent unused by any wire role', WireIssueSeverity.warn));
    }
  }
  for (final ic in {...namedIcons, ...namedGlyphs}) {
    if (!referencedIcons.contains(ic)) {
      out.add(RoleDriftIssue('icons.$ic',
          'theme icon unused by any wire role', WireIssueSeverity.warn));
    }
  }

  out.sort((a, b) => a.role.compareTo(b.role));
  return out;
}
