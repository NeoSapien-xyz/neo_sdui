/// The **role ledger** — figwire's authoring-time accumulator of the *look* it
/// reads from each Figma page but is forbidden (by the Iron Rule) to put on the
/// wire. A single Figma read forks into the wire (semantics) and this ledger
/// (look); pages are fed part by part across runs, so the ledger accumulates and
/// a terminal compile ([reconcile] + `theme_compile.dart`) turns it into one base
/// `NeoSduiTheme` plus a `copyWith` override per divergent page.
///
/// Two sides per page:
/// - the **look** side — raw role→value [Observation]s, each tagged by source
///   page and [Provenance];
/// - the **role-usage** side — the look-role names that page's *wire* emitted
///   (`tone:brand`, `emphasis:high`, `icon:sparkle`), the shared registry the
///   role-drift lint (`role_lint.dart`) checks against.
///
/// [reconcile] is a **batch** function over the full observation set — never an
/// incremental merge at ingest — so its result is independent of the order pages
/// were fed (see the order-independence test).
library;

import 'package:meta/meta.dart';

/// Where a ledger value came from. Drives the compile's inline confidence flags
/// and the guess gate (`theme_compile.dart`'s [inferredRoleGate]).
///
/// - `variable` — bound to a Figma variable (`get_variable_defs`). Emitted plain.
/// - `measured` — read off the node's own properties (`get_design_context`'s type
///   / fills / effects). Exact, just not token-bound. Emitted plain.
/// - `inferred` — **guessed**: eyeballed off a screenshot, or interpolated into a
///   scale nobody read. Emits `// confirm:` and fails the gate.
/// - `todo` — Figma could not answer; the compile emits a fallback value plus
///   `// TODO(theme):`.
///
/// `measured` exists because `variable` is not reachable for most roles: a
/// starter-tier Figma file caps variables (this design has exactly two), so a
/// taxonomy of *bound-or-guessed* forced every honestly-read value into
/// `inferred`. That made the gate unsatisfiable — the waiver became mandatory,
/// so it gated nothing — and buried the handful of real guesses under 26 false
/// ones, which is precisely why every `// confirm:` got stripped as noise. The
/// line that matters is **read vs. invented**, not *bound vs. unbound*.
enum Provenance { variable, measured, inferred, todo }

/// The shape of a ledger value, so [reconcile] clusters near-duplicates
/// kind-aware: `color` values cluster by RGB distance, everything else by exact
/// match. `color`/`number` values are stored bare (`0xFF00F1A0`, `16`) and the
/// compile wraps them (`Color(0xFF00F1A0)`); `textStyle`/`gradient`/`other`
/// values are stored as the Dart literal and emitted verbatim.
enum ValueKind { color, number, textStyle, gradient, other }

/// Role-key prefixes for the two map-typed theme slots. A roleKey like
/// `accents.brand` / `icons.download` targets a *named* entry in the theme's
/// `accents`/`icons` map; every other roleKey is a scalar field. Shared so the
/// compile and the lint split keys the same way — one literal, no per-file drift.
const String kAccentsPrefix = 'accents.';
const String kIconsPrefix = 'icons.';
const String kGlyphsPrefix = 'glyphs.';

/// The name after [prefix] if [key] starts with it, else null.
String? stripRolePrefix(String key, String prefix) =>
    key.startsWith(prefix) ? key.substring(prefix.length) : null;

/// Parse a `0xAARRGGBB` / `0xRRGGBB` (or bare-hex) literal to an int, or null if
/// unparseable. The one hex parser — [_rgb] here and `theme_compile`'s `Color`
/// wrapping both route through it (DRY: one parser, no per-file drift).
int? parseColorHex(String hex) =>
    int.tryParse(hex.replaceFirst('0x', ''), radix: 16);

/// Lower is more trustworthy — used to keep the best provenance when duplicate
/// observations of one value are folded together.
int _provenanceRank(Provenance p) => switch (p) {
      Provenance.variable => 0,
      Provenance.measured => 1,
      Provenance.inferred => 2,
      Provenance.todo => 3,
    };

/// One observation: a role's value as seen on one page, with where it came from.
@immutable
class Observation {
  const Observation({
    required this.roleKey,
    required this.value,
    required this.page,
    required this.provenance,
    required this.kind,
    this.source,
  });

  /// The `NeoSduiTheme` field this maps to — `accent`, `surface`, `radiusMd`,
  /// `title`, `accents.brand`, `cardGradient`, …
  final String roleKey;

  /// `color`/`number`: a bare literal (`0xFF00F1A0`, `16`). Otherwise: the full
  /// Dart literal (`TextStyle(...)`, `LinearGradient(...)`).
  final String value;
  final String page;
  final Provenance provenance;
  final ValueKind kind;

  /// Where the value was read, so it can be checked again later: a file and
  /// line pinned to a commit (`neo-mcp-guide@55caf81:css/styles.css:353`), a
  /// Figma node, or the shipped app file. Pin the commit — an unmerged source
  /// moves, and a bare line number then points at the wrong rule.
  final String? source;

  Map<String, Object?> toJson() => {
        'roleKey': roleKey,
        'value': value,
        'page': page,
        'provenance': provenance.name,
        'kind': kind.name,
        if (source != null) 'source': source,
      };

  /// Caller must pre-validate the map's shape — these raw casts and `byName`
  /// lookups throw on a malformed entry. [RoleLedger.fromJson] is the only caller
  /// and guards every field before calling this; a new caller must do the same.
  factory Observation.fromJson(Map<String, Object?> json) => Observation(
        roleKey: json['roleKey'] as String,
        value: json['value'] as String,
        page: json['page'] as String,
        provenance: Provenance.values.byName(json['provenance'] as String),
        kind: ValueKind.values.byName(json['kind'] as String),
        source: json['source'] as String?,
      );
}

/// One role's chosen value after reconciliation, plus how many pages back it.
@immutable
class ResolvedRole {
  const ResolvedRole({
    required this.roleKey,
    required this.value,
    required this.kind,
    required this.provenance,
    required this.pageCount,
    this.source,
  });

  final String roleKey;
  final String value;
  final ValueKind kind;
  final Provenance provenance;
  final int pageCount;

  /// The chosen value's source, when its observations carry one. Several pages
  /// can back one value; the first source in sort order is shown, so the report
  /// is stable across feed orders.
  final String? source;
}

/// The batch result: the base value per role, per-page overrides for divergent
/// pages, the roles that genuinely differ across pages (the skill's prompt list),
/// and the set of wire roles used (the lint's input).
@immutable
class Reconciled {
  const Reconciled({
    required this.base,
    required this.overridesByPage,
    required this.conflictRoles,
    required this.usedRoles,
    this.imports = const [],
  });

  /// roleKey → base value (the majority look).
  final Map<String, ResolvedRole> base;

  /// page → {roleKey → override role} for every role where the page diverges
  /// from base. Pages that match base do not appear. Each override is a full
  /// [ResolvedRole] so its provenance rides along — an `inferred` override still
  /// emits its `// confirm:` marker (metadata travels with the value, DTCG-style).
  final Map<String, Map<String, ResolvedRole>> overridesByPage;

  /// Roles with more than one genuine cluster — the skill asks base-vs-override
  /// on these. Sorted for determinism.
  final List<String> conflictRoles;

  /// Every wire role tag named across all pages (`tone:brand`, `emphasis:high`,
  /// `icon:sparkle`) — what `role_lint.dart` resolves against the theme.
  final Set<String> usedRoles;

  /// Pass-through from the ledger, not a reconciliation result: the extra import
  /// URIs the emitted source needs (see [RoleLedger.imports]). It rides here so
  /// `emitTheme` reads it off the same record as the roles — nothing for a caller
  /// to remember to pass alongside.
  final List<String> imports;
}

/// The accumulator. Mutable: pages append across runs. Persist with [toJson] and
/// resume with [fromJson]; [clear] is the `fresh` signal.
class RoleLedger {
  RoleLedger({
    List<Observation>? observations,
    Map<String, Set<String>>? roleUsage,
    List<String>? imports,
    this.malformedObservations = 0,
  })  : observations = observations ?? <Observation>[],
        roleUsage = roleUsage ?? <String, Set<String>>{},
        imports = imports ?? <String>[];

  final List<Observation> observations;

  /// Import URIs the emitted theme needs *beyond* `flutter/widgets.dart` and
  /// `neo_sdui.dart` — whatever the ledger's own Dart literals name:
  /// `package:google_fonts/google_fonts.dart` for a `GoogleFonts.workSans(...)`
  /// title, `package:flutter/material.dart` for an `Icons.*` glyph, an app path
  /// for a grain overlay. Un-imported, those literals do not compile, and the
  /// look degrades to the system font / no icon — silently, because the ledger
  /// still *reads* right. The author writes the literal and names its import;
  /// the compile only makes the import available (deliberately no name→package
  /// table — that would guess, and guessing is the bug this ledger exists to
  /// stop).
  final List<String> imports;

  /// How many observations [fromJson] dropped as malformed on the last load — a
  /// corrupt/truncated ledger write would otherwise silently masquerade as
  /// "Figma had no data". The compile tool surfaces this when non-zero so
  /// accumulator corruption is visible rather than swallowed.
  final int malformedObservations;

  /// page → wire role tags that page used.
  final Map<String, Set<String>> roleUsage;

  /// Record a look observation for a page.
  void observe(Observation o) => observations.add(o);

  /// Record that a page's wire named a look role (e.g. `tone:brand`).
  void useRole(String page, String roleTag) =>
      (roleUsage[page] ??= <String>{}).add(roleTag);

  /// The `fresh` signal — start a new theme instead of accumulating.
  void clear() {
    observations.clear();
    roleUsage.clear();
  }

  /// Batch reconcile over the whole observation set — feeding-order independent.
  /// Per role: cluster near-duplicate values (kind-aware), pick the base cluster,
  /// and emit a per-page override for pages outside it. The base is the cluster
  /// containing [basePage] when it names one (the explicit escape hatch, R8),
  /// else the majority cluster (most pages).
  Reconciled reconcile({int colorThreshold = 24, String? basePage}) {
    final byRole = <String, List<Observation>>{};
    for (final o in observations) {
      (byRole[o.roleKey] ??= <Observation>[]).add(o);
    }

    final base = <String, ResolvedRole>{};
    final overridesByPage = <String, Map<String, ResolvedRole>>{};
    final conflictRoles = <String>[];

    byRole.forEach((roleKey, obs) {
      final clusters = _cluster(obs, colorThreshold)
        ..sort((a, b) {
          final byPages = b.pages.length.compareTo(a.pages.length);
          return byPages != 0 ? byPages : a.canonical.compareTo(b.canonical);
        });
      // Majority by default (clusters are sorted most-pages-first); an explicit
      // basePage overrides that by pinning whichever cluster carries it.
      var baseCluster = clusters.first;
      if (basePage != null) {
        for (final c in clusters) {
          if (c.pages.contains(basePage)) {
            baseCluster = c;
            break;
          }
        }
      }
      base[roleKey] = ResolvedRole(
        roleKey: roleKey,
        value: baseCluster.canonical,
        kind: baseCluster.kind,
        provenance: baseCluster.provenance,
        pageCount: baseCluster.pages.length,
        source: baseCluster.source,
      );
      if (clusters.length > 1) {
        conflictRoles.add(roleKey);
        for (final cl in clusters) {
          if (identical(cl, baseCluster)) continue;
          for (final page in cl.pages) {
            (overridesByPage[page] ??= <String, ResolvedRole>{})[roleKey] =
                ResolvedRole(
              roleKey: roleKey,
              value: cl.canonical,
              kind: cl.kind,
              provenance: cl.provenance,
              pageCount: cl.pages.length,
              source: cl.source,
            );
          }
        }
      }
    });

    final usedRoles = <String>{};
    for (final tags in roleUsage.values) {
      usedRoles.addAll(tags);
    }

    return Reconciled(
      base: base,
      overridesByPage: overridesByPage,
      conflictRoles: conflictRoles..sort(),
      usedRoles: usedRoles,
      imports: imports,
    );
  }

  Map<String, Object?> toJson() => {
        'version': 1,
        'imports': imports,
        'observations': [for (final o in observations) o.toJson()],
        'roleUsage': {
          for (final e in roleUsage.entries) e.key: e.value.toList()..sort(),
        },
      };

  factory RoleLedger.fromJson(Map<String, Object?> json) {
    final obs = <Observation>[];
    var dropped = 0;
    final rawObs = json['observations'];
    if (rawObs is List) {
      for (final e in rawObs) {
        // Skip a malformed observation rather than throwing — the ledger is read
        // from disk, so an unknown enum name or missing field must not abort the
        // whole load (matches the defensive shape-guarding around it). Count the
        // drops so a truncated/corrupt write is visible, not silently swallowed.
        if (e is! Map) {
          dropped++;
          continue;
        }
        final m = Map<String, Object?>.from(e);
        if (m['roleKey'] is! String ||
            m['value'] is! String ||
            m['page'] is! String ||
            !Provenance.values.asNameMap().containsKey(m['provenance']) ||
            !ValueKind.values.asNameMap().containsKey(m['kind']) ||
            (m.containsKey('source') && m['source'] is! String)) {
          dropped++;
          continue;
        }
        obs.add(Observation.fromJson(m));
      }
    }
    final usage = <String, Set<String>>{};
    final rawUsage = json['roleUsage'];
    if (rawUsage is Map) {
      rawUsage.forEach((page, tags) {
        if (page is String && tags is List) {
          usage[page] = {for (final t in tags) if (t is String) t};
        }
      });
    }
    // Non-String entries are dropped like a malformed observation — an import
    // list is a header, not a value, so a bad entry must not abort the load.
    final rawImports = json['imports'];
    final imports = <String>[
      if (rawImports is List)
        for (final i in rawImports)
          if (i is String) i,
    ];
    return RoleLedger(
        observations: obs,
        roleUsage: usage,
        imports: imports,
        malformedObservations: dropped);
  }
}

/// One near-duplicate cluster of observed values for a role.
class _Cluster {
  _Cluster(this.canonical, this.kind);

  /// The representative value (the highest-count value that opened the cluster —
  /// determined from a deterministic sort, so it is feed-order independent).
  final String canonical;
  final ValueKind kind;
  final Set<String> pages = <String>{};
  final Set<String> sources = <String>{};
  Provenance provenance = Provenance.todo;

  String? get source => sources.isEmpty ? null : (sources.toList()..sort()).first;

  void absorb(_Tally t) {
    pages.addAll(t.pages);
    sources.addAll(t.sources);
    if (_provenanceRank(t.provenance) < _provenanceRank(provenance)) {
      provenance = t.provenance;
    }
  }
}

/// Distinct-value tally within one role.
class _Tally {
  _Tally(this.value);
  final String value;
  final Set<String> pages = <String>{};
  final Set<String> sources = <String>{};
  Provenance provenance = Provenance.todo;
}

/// Cluster a role's observations. Deterministic (feed-order independent): tally
/// distinct values, sort by (page-count desc, value asc), then greedily assign
/// each to an existing color cluster within [colorThreshold] or open a new one.
/// Non-color kinds cluster by exact value (threshold ignored).
List<_Cluster> _cluster(List<Observation> obs, int colorThreshold) {
  final kind = obs.first.kind;

  final tally = <String, _Tally>{};
  for (final o in obs) {
    final t = tally.putIfAbsent(o.value, () => _Tally(o.value));
    t.pages.add(o.page);
    if (o.source != null) t.sources.add(o.source!);
    if (_provenanceRank(o.provenance) < _provenanceRank(t.provenance)) {
      t.provenance = o.provenance;
    }
  }

  final ordered = tally.values.toList()
    ..sort((a, b) {
      final byPages = b.pages.length.compareTo(a.pages.length);
      return byPages != 0 ? byPages : a.value.compareTo(b.value);
    });

  final clusters = <_Cluster>[];
  for (final t in ordered) {
    _Cluster? target;
    if (kind == ValueKind.color) {
      for (final cl in clusters) {
        if (_colorDistance(cl.canonical, t.value) <= colorThreshold) {
          target = cl;
          break;
        }
      }
    }
    (target ??= (clusters..add(_Cluster(t.value, kind))).last).absorb(t);
  }
  return clusters;
}

/// Sum of absolute R/G/B channel differences between two `0xAARRGGBB` values.
/// Returns a large sentinel when either value can't be parsed, so unparseable
/// colors never merge.
int _colorDistance(String a, String b) {
  final ca = _rgb(a), cb = _rgb(b);
  if (ca == null || cb == null) return 1 << 20;
  return (ca[0] - cb[0]).abs() + (ca[1] - cb[1]).abs() + (ca[2] - cb[2]).abs();
}

/// [r, g, b] from a `0xAARRGGBB` / `0xRRGGBB` literal, or null if unparseable.
List<int>? _rgb(String hex) {
  final v = parseColorHex(hex);
  if (v == null) return null;
  return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
}
