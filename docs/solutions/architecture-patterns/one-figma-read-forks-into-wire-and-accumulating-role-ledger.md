---
title: "One Figma read, two projections: the wire carries semantics, an accumulating role ledger compiles to the theme"
date: 2026-07-15
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: medium
applies_when:
  - extending a Figma->wire authoring tool (figwire) so one read also yields a look/theme projection
  - deciding whether to re-read a metered/capped source or fork a single read into two projections
  - accumulating design observations across screens fed part-by-part over multiple runs into one artifact
  - reconciling near-duplicate design-token values so the result is independent of feeding order (batch, not incremental)
  - emitting a Dart theme literal where every required constructor argument must be filled to compile
related_components:
  - documentation
  - testing_framework
tags: [neo-sdui, figwire, design-tokens, theme, role-ledger, code-generation, two-projections, batch-reconcile]
---

# One Figma read, two projections: the wire carries semantics, an accumulating role ledger compiles to the theme

## Context

`figwire` turns a Figma selection into neo_sdui wire JSON, and it lives under one
hard constraint — the **Iron Rule**: `NO #hex, px, font, gradient` on the wire.
The wire carries semantics (`tone:brand`, `emphasis:high`, `icon:sparkle`); the
look is resolved later by a `NeoSduiTheme` the app hands to each `NeoSduiView`.

To honor that rule, figwire reads *every pixel* of a selection and then **throws
the look away**. So the app ended up with a wire per screen but no theme to render
it against — and someone hand-built `NeoSduiTheme` by eyeballing Figma a **second
time**. That second pass is manual, error-prone, and expensive: the Figma seat is
capped at ~6 reads/month, and a re-read spends against it for pixels figwire had
already seen and discarded.

Two structural facts shape the fix:

1. **The look figwire discards *is* the theme.** The pixels forbidden on the wire
   are exactly the values `NeoSduiTheme` needs. Keeping them closes the gap with
   no second navigational pass.
2. **Screens arrive part by part.** A guide's pages come in over multiple figwire
   runs, so the theme cannot be produced per screen — it must **accumulate** and
   **resolve once** at the end, and the outcome must not depend on the order pages
   were fed.

The pattern below is the theme companion: one read forks into two projections, an
accumulating ledger, and a terminal compile to a paste-in theme. It is the
mechanized form of three standing preferences in this repo — derive the look from
*one* general mechanism (role palette + wire token), not per-guide code; make two
guides differ only by the `NeoSduiTheme` *data* each view gets; and classify a
"custom" element as look→theme / composition→wire / new-kind→registry (see the
[Related](#related) docs).

The real code lives package-side (pure-Dart, unit-testable) with the skill as the
Figma-facing orchestrator:

- `packages/neo_sdui/lib/src/authoring/theme_ledger.dart` — ledger model, batch `reconcile`
- `packages/neo_sdui/lib/src/authoring/theme_compile.dart` — `kRoleSlots`, `buildBaseTheme`, `emitTheme`, `coverageReport`
- `packages/neo_sdui/lib/src/authoring/role_lint.dart` — `lintRoleDrift`
- `packages/neo_sdui/test/tools/compile_theme_test.dart` — env-gated terminal entrypoint
- `.claude/skills/figwire/references/theme-extract.md` — the extraction contract

---

## Guidance

### Decision 1 — One read forks into two projections

The Iron Rule is preserved, not weakened. A single Figma read produces **both**
outputs; the extracted look goes **only** to a persistent role ledger sidecar,
never onto the wire. There is never a second read.

```
one Figma read ─┬─ wire.json      (semantics → Remote Config)  — unchanged
                └─ role ledger     (look → a per-run sidecar)   — the new half
                        │
                (feed pages part by part, one run each)
                        ▼
                compile ×1 → base NeoSduiTheme + per-page copyWith overrides
```

The wire classifier is untouched — same block vocabulary, same validation gates,
same bytes out. The theme projection rides *alongside* the classifier, not woven
into it. `theme-extract.md` states the rule sharpened: "Every look value you read
goes to the **ledger**, never the wire."

Extraction is **token-layer first**, because the design system's variables are its
source of truth and are higher-fidelity than scraping:

1. `get_variable_defs` — bound color / number / type variables and styles
2. `get_shader_fill` / `get_shader_effect` — gradients mapping onto `cardGradient` / `groupGradient` / `accentGradient`
3. `get_design_context` / REST — exact values when no variable is bound
4. Screenshot — last-resort visual read, marked `inferred`

Token-first is the *fidelity* order, not a *free* one: each of those is a distinct
metered read. On a View seat, read the look from the screenshot by default and
reserve variable/shader calls for when a Dev/Full seat makes them affordable.

### Decision 2 — Persistent accumulating ledger + BATCH reconcile (feeding-order independent)

The ledger is a JSON sidecar the user names (e.g. `.theme/ledger.json`). It has
two sides per page — the **look** side (raw `Observation`s) and the **role-usage**
side (the wire role tags that page emitted, the lint's input):

```jsonc
{
  "version": 1,
  "observations": [
    {"roleKey": "accent", "value": "0xFF00F1A0", "page": "<page>", "provenance": "variable", "kind": "color"},
    {"roleKey": "title",  "value": "TextStyle(fontSize: 24, fontWeight: FontWeight.w500)", "page": "<page>", "provenance": "inferred", "kind": "textStyle"}
  ],
  "roleUsage": { "<page>": ["tone:accent", "emphasis:high", "icon:sparkle"] }
}
```

`clear()` is the `fresh` signal; the default is to **append** — feeding a new
guide's screens does not require manually wiping state, and a mid-guide resume
just continues.

The load-bearing decision is **reconcile is a batch function over the whole
observation set, run at COMPILE — never an incremental merge at ingest.** Near-
duplicate values (`#00F1A0` vs `#00F0A0`, within a color-distance threshold) are
clustered to one canonical value over the *entire* accumulated set; genuine cross-
page differences (amber vs green) are recorded as conflicts. Because the pass sees
all pages at once and orders clusters deterministically, **feeding order cannot
change the outcome** — the exact property an incremental merge would lose (page A
then B could canonicalize to A's value; B then A to B's).

```dart
// theme_ledger.dart — reconcile() runs over the full observation set, per role:
final clusters = _cluster(obs, colorThreshold)
  ..sort((a, b) {
    final byPages = b.pages.length.compareTo(a.pages.length);
    return byPages != 0 ? byPages : a.canonical.compareTo(b.canonical); // deterministic tie-break
  });
```

Clustering itself is order-free: tally distinct values, sort by (page-count desc,
value asc), then greedily assign each to an existing color cluster within
`colorThreshold` (default 24, sum of |ΔR|+|ΔG|+|ΔB|) or open a new one. Non-color
kinds cluster by exact value. Unparseable colors return a large sentinel distance
so they never silently merge.

### Decision 3 — Base = majority look; overrides = minimal per-page diffs; designate-base escape hatch

The base theme is the value **most pages share** per role; a divergent page emits
only its *differing* fields as `base.copyWith(...)`. Pages that match base emit no
override at all. This minimizes both the number and size of overrides — the user
copies the base once, matching pages reuse it, outliers carry a small diff. Chosen
over N standalone themes (more to copy, no shared base).

But majority-by-page-count is only a **proxy for design intent**, and a lopsided
count picks wrong (6 muted detail screens outvote 1 canonical hero). So there is an
explicit escape hatch: `reconcile(basePage: ...)` pins whichever cluster carries
the named page as the base, and the rest become overrides.

```dart
// theme_ledger.dart — majority by default; basePage pins a specific page's cluster:
var baseCluster = clusters.first;               // majority (clusters sorted most-pages-first)
if (basePage != null) {
  for (final c in clusters) {
    if (c.pages.contains(basePage)) { baseCluster = c; break; }  // R8 escape hatch
  }
}
```

Surfaced to the skill as `NEO_THEME_BASE_PAGE=<page>`. A named base beating an
implicit vote is exactly how explicit-source design-token tools resolve this.

### Decision 4 — The bare-TODO compile trap

Dart has no "comment where a value goes." `NeoSduiTheme`'s constructor has 13
**required** params (`accent`, `onAccent`, `surface`, … `title`/`subtitle`/`body`/
`caption`). A required argument **cannot** be replaced by a bare `// TODO` — the
file would not compile, and a theme that does not compile is worse than a hand-
built one. So:

- **The base is always emitted as `NeoSduiTheme.fallback().copyWith(...)`.** Every
  required param is filled by `fallback()`; the compile only overrides the roles it
  actually observed. A role with *no* observation simply inherits `fallback()` and
  is named on a trailing `// TODO(theme): no data for … — inheriting
  NeoSduiTheme.fallback().` line — never an empty arg.
- **`inferred` fields emit their guess plus `// confirm:`.** The chief inferred
  case is the type scale: many Figma font sizes collapse into
  `title`/`subtitle`/`body`/`caption`+`mono`. The value is real and compilable; the
  marker says "eyeball this."
- **A coverage report states, per field, its provenance** — `variable` (read from a
  token, emitted plain), `inferred` (emitted with `// confirm:`), or `todo`
  (inherited fallback). This is what the user signs off against.

```dart
// theme_compile.dart — the base ALWAYS starts from fallback().copyWith(...):
..writeln('final base = NeoSduiTheme.fallback().copyWith(');
// ...
final confirm = role.provenance == Provenance.inferred ? '  // confirm:' : '';
b.writeln('  $key: $expr,$confirm');
```

`emitTheme` also **validates every emitted value before writing it** (the review
fix in commit df469c3, "validate emitted values"): a role whose ledger `kind`
disagrees with the registry slot, or a color/number that does not parse, is
*skipped* rather than printed as invalid Dart (e.g. it will not print `radiusMd: 16`
into a `BorderRadius` field). Skipped roles are collected and reported on their own
`// TODO(theme): unresolved …` line. The net guarantee: **the pasted theme always
compiles.**

### Decision 5 — A single authoritative role registry reconciles wire ↔ theme

`kRoleSlots` in `theme_compile.dart` is the single source of truth — the DTCG /
Style-Dictionary "token map" analog — for every scalar role the compile supports:
its `ValueKind` and, for the color/number roles the preview paints, how it lands on
a live theme. Add a theme field **there once** and both the live render preview
(`buildBaseTheme`) and the paste-in source (`emitTheme`) pick it up; an unknown
roleKey is *flagged*, never silently half-handled. **The registry's kind is
authoritative** — `buildBaseTheme` trusts `slot.kind`, not the ledger's self-
declared one (commit df469c3, "make registry kind authoritative"):

```dart
// theme_compile.dart — the registry's kind wins over the ledger's:
if (role.kind == slot!.kind) theme = live(theme, role.value);  // else skipped, stays fallback
```

On top of the registry, `role_lint.dart` asserts the wire↔theme coupling **both
ways**, over every role named across *all* accumulated pages (`usedRoles`):

- A wire role with **no theme slot** is a **blocking** issue — `tone:brand` with no
  `accents.brand` (and not a built-in `accent`/`critical`) would render flat.
- A theme slot **no wire uses** is an **advisory** — dead look, worth pruning.

```dart
// role_lint.dart — wire role → theme slot, blocking:
if (!kBuiltinAccentTones.contains(name) && !namedAccents.contains(name)) {
  out.add(RoleDriftIssue(tag, "wire tone '$name' has no theme accent slot", WireIssueSeverity.block));
}
```

It reuses `WireIssueSeverity` so the theme gate speaks the same block/warn
vocabulary as the wire's own `validateWireVocabulary`, and runs as a gate inside
`compile_theme_test.dart` (the entrypoint `expect(blocking, isEmpty)`). `emphasis:*`
always resolves via the built-in fill, so it never drifts.

---

## Why This Matters

- **Fork over re-read (D1):** the seat cap makes a second navigational pass a real
  cost. Forking one read spends nothing extra beyond the token/shader calls already
  available in that pass — and it keeps wire and theme *reconciled on one role
  vocabulary*, so neither drifts from the other. Skip it and you are back to hand-
  eyeballing Figma a second time, at ~1/6th of a month's budget per re-read.
- **Batch not incremental (D2):** if reconciliation happened at ingest, the theme
  a guide produces would depend on *which page you fed first* — a silent, un-
  reproducible dependency on operator order. Batch-at-compile makes the output a
  pure function of the observation *set*. The order-independence test guards
  exactly this; it is the single most important invariant in the ledger.
- **Base + minimal overrides (D3):** N standalone themes means the user copies N
  full themes and there is no shared base to edit once. Majority-base + diff
  overrides means one copy + tiny diffs — but *only* if the escape hatch exists,
  because a proxy (page count) will eventually mis-rank intent, and without
  `basePage` the user would have no recourse but to re-tag the ledger by hand.
- **Bare-TODO trap (D4):** this is the difference between a paste-in that *runs*
  and one that red-squiggles on paste. A theme fails by rendering *wrong*, not by
  vanishing — so the value of the emitted artifact is that it compiles *and* tells
  you precisely which fields to trust (`variable`), sanity-check (`confirm`), or
  fill in (`todo`). A bare comment in a required slot throws all of that away.
- **One registry, two-way lint (D5):** two lists (one for the live preview, one for
  the emitted source) rot out of sync — the preview paints a role the paste-in
  drops, or vice versa. One `kRoleSlots` makes that class of bug unrepresentable.
  The two-way lint catches the two silent failures the wire's own gates *cannot*:
  a wire role that renders flat (blocking), and dead theme look (advisory).

---

## When to Apply

This generalizes past figwire to any of these shapes:

- **An authoring tool that reads a rich source but must emit a *value-clean
  semantic* artifact plus a *separate look/config* artifact.** Any "keep semantics
  pure, but don't throw the styling away" split: fork the single read into the
  clean artifact and a sidecar; never re-read the source to recover what you
  already saw. (Here: wire vs theme, from one Figma read.)
- **Any cross-run accumulation that must be feeding-order independent.** If results
  are assembled from inputs arriving over time and the outcome must not depend on
  arrival order, **store raw observations and reconcile in one batch pass at the
  end** — do not fold/merge incrementally at ingest. Add an explicit order-
  independence test.
- **Any code-emitter filling a required-arg constructor (or schema) from partial
  data.** When the target has required fields you may not have data for, emit from a
  known-good default (`fallback().copyWith(...)`) and override only what you have;
  never leave a bare placeholder in a required slot. Carry per-field provenance and
  surface it as inline markers (`// confirm:`) + a coverage report, so the consumer
  knows what to trust.
- **Any majority/frequency heuristic that stands in for intent.** Ship the majority
  default *and* an explicit designate-the-source escape hatch — the proxy will
  eventually mis-rank, and the override is cheap.
- **Any pair of coupled artifacts sharing a vocabulary.** Put the vocabulary in one
  authoritative registry both sides read, and lint the coupling *both ways* (unmet
  reference = error; unused definition = advisory).

---

## Examples

**Emitted paste-in theme (real output of the U6 dry-run).** Run:

```bash
cd packages/neo_sdui && NEO_THEME_LEDGER=test/tools/testdata/theme_ledger_fixture.json \
  fvm flutter test test/tools/compile_theme_test.dart
```

Emits a `.dart` file (base is `NeoSduiTheme.fallback().copyWith(...)`; `variable`
colors plain; the inferred type scale and gradient carry `// confirm:`):

```dart
// Generated by figwire theme-compile — review every `confirm` and `todo` marker before shipping.
import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

final base = NeoSduiTheme.fallback().copyWith(
  accent: Color(0xFF00F1A0),
  accentGradient: LinearGradient(colors: [Color(0xFF2DF790), Color(0xFF00F1A0)], begin: Alignment.topLeft, end: Alignment.bottomRight),  // confirm:
  background: Color(0xFF0A0A0A),
  body: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, height: 1.2, fontWeight: FontWeight.w400, letterSpacing: -0.3),  // confirm:
  caption: TextStyle(color: Color(0xFF868686), fontSize: 12, height: 1.3, fontWeight: FontWeight.w400, letterSpacing: -0.48),  // confirm:
  danger: Color(0xFFFF5A5F),
  onAccent: Color(0xFF0A0A0A),
  onSurface: Color(0xFFFFFFFF),
  radiusMd: BorderRadius.all(Radius.circular(16)),
  subtitle: TextStyle(color: Color(0xFF868686), fontSize: 14, height: 1.3, fontWeight: FontWeight.w400, letterSpacing: -0.5),  // confirm:
  surface: Color(0xFF202423),
  textMuted: Color(0xFF868686),
  textPrimary: Color(0xFFFFFFFF),
  title: TextStyle(color: Color(0xFFFFFFFF), fontSize: 24, height: 1.16, fontWeight: FontWeight.w500, letterSpacing: -1),  // confirm:
  warning: Color(0xFFFFC107),
);
```

…and a coverage report to stdout, per-field provenance the user signs off against:

```text
Theme coverage — 15 roles:
  variable: accent, background, danger, onAccent, onSurface, radiusMd, surface, textMuted, textPrimary, warning
  inferred: accentGradient, body, caption, subtitle, title
```

**A divergent page → minimal override (from the compile's design, D3).** Three
pages share the look; one page ("Featured") diverges only on `accent`. The compile
emits the majority as base and *only the differing field* as a named override:

```dart
final base = NeoSduiTheme.fallback().copyWith(
  accent: Color(0xFF00F1A0),
  // …shared roles…
);

final featured = base.copyWith(
  accent: Color(0xFFFFC107),   // the ONLY field that differs; everything else inherits base
);
```

An override that diverges on a named accent spreads the base's map
(`...base.accents`) so it does not silently drop base's other accents; an emitted
`icons` block spreads `kDefaultIcons` for the same reason.

**Before → after (the friction this removes):**

- **Before:** figwire writes `wire.json`, discards the look. A human opens Figma a
  *second time* (~1/6 of the monthly seat), eyeballs hex/px/font, and hand-writes
  `NeoSduiTheme(...)` — filling all 13 required params by hand, with no record of
  which values were read vs guessed.
- **After:** the same single read appends look + role-usage to the ledger. When all
  pages are in, `compile_theme_test.dart` reconciles the whole set in one order-
  independent batch, emits a compilable `NeoSduiTheme.fallback().copyWith(...)` base
  + per-page overrides + a provenance coverage report, and fails the run if any wire
  role has no theme slot. Zero second reads; every field labeled read / confirm /
  todo.

**The bare-TODO trap, concretely (D4).** A role with no observation is *never*
emitted as an empty required arg. It inherits `fallback()` and is named on a
trailing line the reviewer acts on:

```dart
// TODO(theme): no data for cardGradient, gridLine — inheriting NeoSduiTheme.fallback().
```

---

## Related

- [Authoring resilient-runtime SDUI needs a strict vocabulary gate the runtime deliberately omits](authoring-wire-needs-strict-vocabulary-gate.md) — the **other** projection of the same single Figma read. That doc governs the *wire* fork (the strict vocabulary gate the resilient runtime omits); this one governs the *look* fork. Same figwire pipeline, same "one read, pixels off the wire" premise, opposite output.
- [Server-driven UI: the wire carries semantics, the client owns the look](sdui-look-is-client-owned.md) — the parent principle. It establishes *where* the look lives (a client-owned `NeoSduiTheme`, selected not defined) at **render** time and names the three homes (look→theme / composition→wire / new-kind→registry). This doc is the **authoring-time** derivation of that same theme.
- [The accent text gradient is theme-owned](accent-text-gradient-theme-owned.md) — a concrete theme-owned, pixels-off-wire look (gradient via a nullable slot + `copyWith`), and the "null default = byte-identical / no golden churn" idea the base+override compile relies on.
- `CONCEPTS.md` → **Role ledger** — the shared vocabulary this pattern is built on (the persistent cross-screen accumulator). This doc is the reusable architecture behind that term; the entry is the term's definition.
