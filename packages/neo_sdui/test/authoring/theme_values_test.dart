/// The **look asserted as data** — no widget, no pump, no font file, no network.
/// The look fails by rendering wrong, not by vanishing, so the wire gates cannot
/// see it; but the values themselves are plain data on the ledger, and some of
/// what shipped broken is visible right here: a `fontFamily:` literal that
/// silently resolves to the system fallback, a gradient with no handles.
///
/// Only what the ledger can *prove*. A wrong-but-plausible value (a `fontSize`
/// the design never uses) is indistinguishable from a right one at this layer —
/// that is `provenance`'s job, not a regex's. Detectors that guessed at it from
/// shape got deleted; see the note in [main].
///
/// Asserts on `reconcile()`'s base — the values the compile hands off — never on
/// `buildBaseTheme(...)`: `kRoleSlots` registers the textStyle/gradient roles
/// with **no `live` painter** (`theme_compile.dart:92-101`), so a built theme
/// leaves them at `fallback()` and the literals ride the emitted source alone.
/// Reading the reconciled values also keeps this off `emitTheme`, so a
/// provenance gate on the compile never gates these assertions.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// The real hand-off when there is one — `NEO_THEME_LEDGER` is the same variable
/// the verify step passes — else the fixture below. `deliverables/` is
/// gitignored, so a clean checkout has no ledger and the fixture keeps the
/// detectors exercised rather than inert.
///
/// The fallback path is one family's (`mcp`). Any other family that forgets
/// `NEO_THEME_LEDGER` would otherwise fall through to a fixture *designed to
/// pass* and report green on nothing — so the source is announced on every run.
/// A green here means nothing until you have read which ledger it graded.
RoleLedger _ledger() {
  final env = Platform.environment['NEO_THEME_LEDGER'];
  final path = env ?? '../../deliverables/mcp/theme_ledger.json'; // cwd = package root
  final file = File(path);
  final real = file.existsSync();
  // ignore: avoid_print — the whole point is that a green run names its subject.
  print(real
      ? 'theme_values: grading ${env == null ? 'the default mcp ledger' : 'NEO_THEME_LEDGER'} → $path'
      : 'theme_values: NO LEDGER AT $path — grading the built-in FIXTURE. '
          'These detectors proved themselves, not your theme. Pass '
          'NEO_THEME_LEDGER=<ledger> to grade a real hand-off.');
  return real
      ? RoleLedger.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>)
      : _fixture();
}

/// roleKey → Dart literal, for every base role of [kind].
Map<String, String> _ofKind(Reconciled r, ValueKind kind) => {
      for (final e in r.base.entries)
        if (e.value.kind == kind) e.key: e.value.value,
    };

void main() {
  final ledger = _ledger();
  final r = ledger.reconcile();
  final text = _ofKind(r, ValueKind.textStyle);

  // There was a third detector here: "letterSpacing is not one broadcast
  // constant across the type scale", on the theory that a uniform
  // |letterSpacing / fontSize| across every role is the signature of one
  // invented tracking value scaled by size. The design falsifies it. Node
  // 4146:13609 tracks -4% deliberately and almost everywhere — 24px/-0.96,
  // 14px/-0.56, 13px/-0.52, 12px/-0.48 — so the detector fired on `title` and
  // `caption`, whose values are character-exact. It was a taste claim ("a real
  // scale tightens display sizes") dressed as a fact, and the only way to
  // satisfy it was to fabricate variety the design does not have. Deleted
  // rather than tuned: the premise is wrong, not the threshold. What it was
  // reaching for — a fontSize that appears nowhere in the design — is real but
  // invisible from the ledger alone, which records no inventory of the design's
  // sizes. That one is caught by `provenance:"inferred"` and its gate.

  test('every observation names where its value was read', () {
    // A value with no source line cannot be re-checked against the design, so
    // "measured" on it is a claim nobody can audit. Pin each one: the PWA file
    // and line at a fixed commit, the Figma node, or the shipped app file.
    final unsourced = [
      for (final o in ledger.observations)
        if (o.source == null || o.source!.trim().isEmpty) '${o.page}:${o.roleKey}',
    ];
    expect(unsourced, isEmpty,
        reason: 'observations with no source: ${unsourced.join(', ')}');
  });

  test('no text role binds its family with a bare fontFamily literal', () {
    // google_fonts registers under an internal family name, so a literal
    // `fontFamily: 'Work Sans'` resolves to the SYSTEM FALLBACK and the screen
    // ships in the wrong face. `fontFamilyFallback:` is not the binding and is
    // fine; only the primary family has to come from the call.
    final bare = RegExp('\\bfontFamily:\\s*[\'"]');
    text.forEach((role, v) {
      expect(bare.hasMatch(v), isFalse,
          reason: '$role binds its family with a literal string — google_fonts '
              'registers under an internal family name, so this renders as the '
              'system fallback. Emit a GoogleFonts.* call, or leave it unset.');
    });
  });

  test('every LinearGradient role carries begin/end', () {
    // Flutter's LinearGradient defaults to HORIZONTAL (`painting/gradient.dart`
    // — `this.begin = Alignment.centerLeft`) while Figma's default handle is
    // vertical, so an omitted handle silently rotates the gradient 90°. Today's
    // ledger sets all four: this guards a hazard class, it is not a live bug.
    _ofKind(r, ValueKind.gradient).forEach((role, v) {
      if (!v.startsWith('LinearGradient')) return; // radial/sweep: no handles
      for (final handle in const ['begin', 'end']) {
        expect(v, matches(RegExp('\\b$handle:')),
            reason: '$role omits `$handle:` — LinearGradient then defaults to '
                'horizontal, rotating the Figma handle 90°.');
      }
    });
  });
}

/// A minimally sane ledger — what an extracted scale actually looks like: bound
/// families, gradients with handles.
RoleLedger _fixture() => RoleLedger(observations: [
      _obs('title', ValueKind.textStyle,
          'GoogleFonts.workSans(fontSize: 24, letterSpacing: -0.5)'),
      _obs('body', ValueKind.textStyle, 'GoogleFonts.workSans(fontSize: 16)'),
      _obs('caption', ValueKind.textStyle,
          'GoogleFonts.workSans(fontSize: 12, letterSpacing: 0.2)'),
      _obs(
          'ctaGradient',
          ValueKind.gradient,
          'LinearGradient(colors: [Color(0xFF00F1A0), Color(0xFF1CA175)], '
              'begin: Alignment.topCenter, end: Alignment.bottomCenter)'),
    ]);

Observation _obs(String role, ValueKind kind, String value) => Observation(
    roleKey: role,
    value: value,
    page: 'base',
    provenance: Provenance.variable,
    kind: kind,
    source: 'fixture');
