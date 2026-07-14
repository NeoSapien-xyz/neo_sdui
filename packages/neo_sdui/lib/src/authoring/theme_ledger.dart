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

/// Where a ledger value came from. Drives the compile's inline confidence flags:
/// `variable`/`inferred` emit the value (the latter with a `// confirm:` marker),
/// `todo` means Figma could not answer and the compile emits a fallback value
/// plus `// TODO(theme):`.
enum Provenance { variable, inferred, todo }

/// The shape of a ledger value, so [reconcile] clusters near-duplicates
/// kind-aware: `color` values cluster by RGB distance, everything else by exact
/// match. `color`/`number` values are stored bare (`0xFF00F1A0`, `16`) and the
/// compile wraps them (`Color(0xFF00F1A0)`); `textStyle`/`gradient`/`other`
/// values are stored as the Dart literal and emitted verbatim.
enum ValueKind { color, number, textStyle, gradient, other }

/// Lower is more trustworthy — used to keep the best provenance when duplicate
/// observations of one value are folded together.
int _provenanceRank(Provenance p) => switch (p) {
      Provenance.variable => 0,
      Provenance.inferred => 1,
      Provenance.todo => 2,
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

  Map<String, Object?> toJson() => {
        'roleKey': roleKey,
        'value': value,
        'page': page,
        'provenance': provenance.name,
        'kind': kind.name,
      };

  factory Observation.fromJson(Map<String, Object?> json) => Observation(
        roleKey: json['roleKey'] as String,
        value: json['value'] as String,
        page: json['page'] as String,
        provenance: Provenance.values.byName(json['provenance'] as String),
        kind: ValueKind.values.byName(json['kind'] as String),
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
  });

  final String roleKey;
  final String value;
  final ValueKind kind;
  final Provenance provenance;
  final int pageCount;
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
  });

  /// roleKey → base value (the majority look).
  final Map<String, ResolvedRole> base;

  /// page → {roleKey → override value} for every role where the page diverges
  /// from base. Pages that match base do not appear.
  final Map<String, Map<String, String>> overridesByPage;

  /// Roles with more than one genuine cluster — the skill asks base-vs-override
  /// on these. Sorted for determinism.
  final List<String> conflictRoles;

  /// Every wire role tag named across all pages (`tone:brand`, `emphasis:high`,
  /// `icon:sparkle`) — what `role_lint.dart` resolves against the theme.
  final Set<String> usedRoles;
}

/// The accumulator. Mutable: pages append across runs. Persist with [toJson] and
/// resume with [fromJson]; [clear] is the `fresh` signal.
class RoleLedger {
  RoleLedger({
    List<Observation>? observations,
    Map<String, Set<String>>? roleUsage,
  })  : observations = observations ?? <Observation>[],
        roleUsage = roleUsage ?? <String, Set<String>>{};

  final List<Observation> observations;

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
  /// Per role: cluster near-duplicate values (kind-aware), pick the base cluster
  /// by page count, and emit a per-page override for pages outside it.
  Reconciled reconcile({int colorThreshold = 24}) {
    final byRole = <String, List<Observation>>{};
    for (final o in observations) {
      (byRole[o.roleKey] ??= <Observation>[]).add(o);
    }

    final base = <String, ResolvedRole>{};
    final overridesByPage = <String, Map<String, String>>{};
    final conflictRoles = <String>[];

    byRole.forEach((roleKey, obs) {
      final clusters = _cluster(obs, colorThreshold)
        ..sort((a, b) {
          final byPages = b.pages.length.compareTo(a.pages.length);
          return byPages != 0 ? byPages : a.canonical.compareTo(b.canonical);
        });
      final baseCluster = clusters.first;
      base[roleKey] = ResolvedRole(
        roleKey: roleKey,
        value: baseCluster.canonical,
        kind: baseCluster.kind,
        provenance: baseCluster.provenance,
        pageCount: baseCluster.pages.length,
      );
      if (clusters.length > 1) {
        conflictRoles.add(roleKey);
        for (final cl in clusters.skip(1)) {
          for (final page in cl.pages) {
            (overridesByPage[page] ??= <String, String>{})[roleKey] = cl.canonical;
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
    );
  }

  Map<String, Object?> toJson() => {
        'version': 1,
        'observations': [for (final o in observations) o.toJson()],
        'roleUsage': {
          for (final e in roleUsage.entries) e.key: e.value.toList()..sort(),
        },
      };

  factory RoleLedger.fromJson(Map<String, Object?> json) {
    final obs = <Observation>[];
    final rawObs = json['observations'];
    if (rawObs is List) {
      for (final e in rawObs) {
        if (e is Map) {
          obs.add(Observation.fromJson(Map<String, Object?>.from(e)));
        }
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
    return RoleLedger(observations: obs, roleUsage: usage);
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
  Provenance provenance = Provenance.todo;

  void absorb(_Tally t) {
    pages.addAll(t.pages);
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
  final v = int.tryParse(hex.replaceFirst('0x', ''), radix: 16);
  if (v == null) return null;
  return [(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF];
}
