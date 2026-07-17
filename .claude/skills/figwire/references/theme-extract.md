# theme-extract — the look projection (figwire's second output)

The wire is the *semantics* projection of a Figma read; the **theme** is the
*look* projection of the **same** read. figwire already sees every pixel and
throws it away to honor the Iron Rule — this keeps exactly what it discards, in a
separate file that never touches the wire.

```
one Figma read ─┬─ wire.json      (semantics → Remote Config)  — unchanged
                └─ role ledger     (look → a per-run sidecar)   — this reference
                        │
                (feed pages part by part)
                        ▼
                compile ×1 → base NeoSduiTheme + per-page copyWith overrides
```

**Contents** — §3 and §4 are where runs die; do not stop reading at §2.
[§1 Extract look](#1-extract-look--the-theme-path-of-ingestionmds-ingest-matrix) ·
[§2 Append to the role ledger](#2-append-to-the-role-ledger) ·
[**§3 Provenance is not decoration**](#3-provenance-is-not-decoration) — the compile *fails* on `inferred`; never strip `// confirm:` ·
[**§4 Compile**](#4-compile--the-terminal-step) — the terminal step, one command ·
[§5 Hybrid conflict prompt](#5-hybrid-conflict-prompt-the-one-human-call) ·
[§6 Hand off](#6-hand-off) — the coverage report

## The Iron Rule still holds — sharpened

`NO #hex, px, font, gradient` on the **wire**. Every look value you read goes to
the **ledger**, never the wire. The rule is unchanged; the theme is where the
discarded pixels finally have a home.

## 1. Extract look — the theme path of `ingestion.md`'s ingest matrix

`get_design_context` **first** — it is the only call carrying type / fill / effect —
plus `get_variable_defs` for the roles that are actually token-bound, and
`get_shader_fill` / `get_shader_effect` for gradients. The screenshot is the last
rung, not the first: everything it feeds is `inferred`, and `inferred` fails the
compile. Unit conversions (letterSpacing, gradient `begin`/`end`) are there too.

## 2. Append to the role ledger

The ledger is a JSON sidecar the user names (e.g. `.theme/ledger.json`). It
accumulates across runs — **continue** by default; start a **fresh** ledger only
for a genuinely new theme. Shape:

```jsonc
{
  "version": 1,
  // Import URIs the emitted theme.dart needs. emitTheme ALWAYS writes
  // `flutter/widgets.dart` + `neo_sdui/neo_sdui.dart` and nothing else — so any
  // value naming a symbol outside those two is uncompilable unless you declare
  // its import here. This is not optional bookkeeping: it is the only reason a
  // `GoogleFonts.*` binding or an app widget survives a recompile.
  "imports": [
    "package:google_fonts/google_fonts.dart",              // any GoogleFonts.* text role
    "package:neo/view/widgets/common/cards/card_grain_overlay.dart"  // a grainOverlay builder
  ],
  "observations": [
    // one per look role seen on this page
    // bound to a Figma variable — rare; most files have only a handful
    {"roleKey": "accent", "value": "0xFF00F1A0", "page": "<page>", "provenance": "variable", "kind": "color"},
    // read off the node's own properties — THE NORMAL CASE, not a lesser one (§3)
    {"roleKey": "title",  "value": "GoogleFonts.workSans(fontSize: 24, fontWeight: FontWeight.w500)", "page": "<page>", "provenance": "measured", "kind": "textStyle"}
  ],
  "roleUsage": {
    // the wire roles THIS page's wire named — the lint's registry
    "<page>": ["tone:accent", "emphasis:high", "icon:sparkle"]
  }
}
```

**Never write a bare `fontFamily:` into a `textStyle` value.** google_fonts registers its families
under an internal name, so `TextStyle(fontFamily: 'Work Sans', …)` resolves to the **system
fallback** — the guide shipped to a device that way and it was the first thing the user saw. Emit the
binding call the app really uses (`GoogleFonts.workSans(fontSize: 24, …)`) and declare
`package:google_fonts/google_fonts.dart` in `imports`. `theme_values_test.dart` fails on the bare
literal; a missing import fails `flutter analyze <theme.dart>`. The same rule covers any app-owned
symbol — a `grainOverlay` builder, an `AppIcons` glyph: **name the symbol, declare its import.**

- **`roleKey`** = the `NeoSduiTheme` field name. **Read the names out of the single
  `kRoleSlots` registry in `theme_compile.dart`** — the compile's source of truth
  (DTCG "token map" style). Do not trust a list copied into prose: the one that used
  to sit here had already rotted past `titleGradient` and `grainOverlay`, the two
  roles the user asked for four times each. A named accent hue is `accents.<name>`;
  a named icon is `icons.<name>`. A roleKey **not** in the registry is emitted as a
  `// TODO(theme): unsupported role` comment, never as a broken `copyWith` arg — so
  a `NeoSduiTheme` field that was never registered is **silently dropped on every
  compile**. If you need one that isn't there, add it to `kRoleSlots` once; the live
  preview and the paste-in source both pick it up (no second list to keep in sync).
- **`kind` → how `value` is written:**
  - `color` — a bare 8-hex literal, `0xFF00F1A0` (the compile wraps it `Color(...)`).
  - `number` — a bare number, `16`.
  - `textStyle` / `gradient` / `other` — the **Dart literal** verbatim
    (`TextStyle(...)`, `LinearGradient(...)`, `BorderRadius.all(Radius.circular(16))`).
- **`provenance`** — `variable` (bound to a token via `get_variable_defs`) and
  `measured` (read off the node's own properties via `get_design_context`) both
  → emitted plain, both pass the gate; `inferred` (**guessed** — eyeballed off a
  screenshot, or interpolated into a scale nobody read) → emitted with
  `// confirm:` and **fails the compile**; `todo` (Figma couldn't answer) → the
  field inherits `NeoSduiTheme.fallback()` and is listed under `// TODO(theme):`.
  The line is **read vs. invented**, not bound vs. unbound.
- **`roleUsage`** — as you classify each wire block, record every `tone:`,
  `emphasis:`, `icon:` role it names. This is the shared registry the role-drift
  lint checks: a `tone:brand` here with no `accents.brand` in the ledger is a
  blocking lint issue.

## 3. Provenance is not decoration

**`inferred` means you guessed.** Not "unbound", not "unconfirmed" — *invented*.
The compile treats it as a defect: **any `inferred` role exits non-zero**, unless
`NEO_THEME_ALLOW_INFERRED=1`, which is an *acknowledgement* (it ships the guess),
never a fix.

`measured` is the normal case and carries no shame: a value read straight off the
node via `get_design_context` is exact — it simply has no token name. **Do not
downgrade a measured value to `inferred` because it wasn't in
`get_variable_defs`.** That mistake is what broke the first MCP theme. Its ledger
came back 26/29 `inferred`, which read as "90% of this look was guessed" — but
the file is starter-tier and exposes *exactly two* variables, so `variable` was
unreachable for 26 roles and almost all of them had been honestly read. The
consequences compounded:

- the gate became **unsatisfiable**, so the waiver was mandatory and gated nothing;
- 26 `// confirm:` markers on values that needed no confirming read as noise, so
  **every one got stripped** — and the flags on the handful of real guesses went
  with them.

Re-graded on the read-vs-invented line, the same ledger was 3 `variable`, 25
`measured`, **2 actually guessed** (`warning`, `mono`) — two names a human can
act on in a minute. A gate that fires on everything is a gate nobody reads.

**Never strip a `// confirm:`** from the emitted source — it is the only thing
telling the human which values were read and which were invented. A noisy marker
means confirm the value, not delete the flag; if the markers are so many that
they read as noise, suspect *this* bug — you are probably calling measured values
guesses.

## 4. Compile — the terminal step

When all pages are in, run the compile (it reconciles the whole ledger in one
batch — feeding order does not matter):

```bash
NEO_THEME_LEDGER=<ledger.json> NEO_THEME_OUT=<theme.dart> \
  [NEO_THEME_BASE_PAGE=<page>] \
  fvm flutter test packages/neo_sdui/test/tools/compile_theme_test.dart
```

It prints the paste-in `NeoSduiTheme` source (a `base` plus a named
`base.copyWith(...)` per divergent page), the coverage report, and runs the
role-drift lint (fails on a wire role with no theme slot). `NEO_THEME_OUT` writes
the source to a file.

- **Base = the majority look** across pages; only a page that genuinely differs
  emits an override, carrying only its differing fields.
- **Near-duplicate values auto-merge** (a trivial `#00F1A0` vs `#00F0A0` drift is
  one value, no override).
- **`NEO_THEME_BASE_PAGE=<page>` pins that page's look as the base** regardless of
  page-count majority (the escape hatch, §5) — every other page's differing look
  becomes an override.

## 5. Hybrid conflict prompt (the one human call)

The compile's coverage report names **conflict roles** — roles where pages
genuinely differ. For each, ask the user the one question that isn't inferable:

> Role `accent` differs — `#00F1A0` (pages A, B) vs `#FFC107` (page C). Is
> `#FFC107` a **per-page override** for page C, or should it be the **base**?

Near-dupes never reach this prompt (auto-merged); only real design differences
do. Default: majority = base, minority = override. **Escape hatch:** if the user
says a *specific* page's look should be the base (e.g. the majority pages are
placeholders and one hero screen is canonical), re-run the compile with
`NEO_THEME_BASE_PAGE=<page>` to pin it — the majority then emits overrides
instead. This is the explicit-source approach design-token tools take (a named
base beats an implicit vote).

## 6. Hand off

Give the user the emitted `theme.dart` (base + overrides) plus the coverage
report, flagging every `// confirm:` (inferred) and `// TODO(theme):` (no data)
for review. The theme is pasted into the app; the app decides which
`NeoSduiTheme` each `NeoSduiView` gets (route/guide → theme is app wiring, not
figwire's job).
