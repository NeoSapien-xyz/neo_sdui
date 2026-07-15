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

## The Iron Rule still holds — sharpened

`NO #hex, px, font, gradient` on the **wire**. Every look value you read goes to
the **ledger**, never the wire. The rule is unchanged; the theme is where the
discarded pixels finally have a home.

## 1. Extract look, token-layer first

Prefer Figma's structured token layer over scraping pixels (it is the design
system's source of truth):

1. **`get_variable_defs`** — bound color / number / type variables and styles.
2. **`get_shader_fill` / `get_shader_effect`** — gradient fills that map onto
   `cardGradient` / `groupGradient` / `accentGradient`.
3. **`get_design_context` / REST** — exact values when no variable is bound.
4. **Screenshot** — last-resort visual read; mark these `inferred`.

**Seat budget:** these are distinct Figma reads metered against the ~6/month cap
(see `ingestion.md`). Token-first is the *fidelity* order, not a free one — on a
View seat, read the look from the screenshot by default and reserve
`get_variable_defs`/shader calls for when a Dev/Full seat makes them affordable.

## 2. Append to the role ledger

The ledger is a JSON sidecar the user names (e.g. `.theme/ledger.json`). It
accumulates across runs — **continue** by default; start a **fresh** ledger only
for a genuinely new theme. Shape:

```jsonc
{
  "version": 1,
  "observations": [
    // one per look role seen on this page
    {"roleKey": "accent", "value": "0xFF00F1A0", "page": "<page>", "provenance": "variable", "kind": "color"},
    {"roleKey": "title",  "value": "TextStyle(fontSize: 24, fontWeight: FontWeight.w500)", "page": "<page>", "provenance": "inferred", "kind": "textStyle"}
  ],
  "roleUsage": {
    // the wire roles THIS page's wire named — the lint's registry
    "<page>": ["tone:accent", "emphasis:high", "icon:sparkle"]
  }
}
```

- **`roleKey`** = the `NeoSduiTheme` field name: `accent`, `onAccent`, `surface`,
  `onSurface`, `danger`, `warning`, `background`, `textPrimary`, `textMuted`,
  `title`/`subtitle`/`body`/`caption`/`mono`, `radiusSm`/`Md`/`Lg`,
  `spaceSm`/`Md`/`Lg`, `blockSpacing`, `backdropBlur`, `cardColor`, `cardPadding`,
  `cardShape`, `cardShadow`, `cardGradient`, `gridLine`, `gridSpacing`,
  `groupGradient`, `divider`, `contentPadding`, `motionDuration`/`motionCurve`/
  `reduceMotion`, `accentGradient`. A named accent hue is `accents.<name>`; a
  named icon is `icons.<name>`. The authoritative list is the single `kRoleSlots`
  registry in `theme_compile.dart` (the compile's source of truth — DTCG "token
  map" style); a roleKey **not** in it is emitted as a `// TODO(theme): unsupported
  role` comment, never as a broken `copyWith` arg. If you need a field that isn't
  there, add it to `kRoleSlots` once — the live preview and the paste-in source
  both pick it up (no second list to keep in sync).
- **`kind` → how `value` is written:**
  - `color` — a bare 8-hex literal, `0xFF00F1A0` (the compile wraps it `Color(...)`).
  - `number` — a bare number, `16`.
  - `textStyle` / `gradient` / `other` — the **Dart literal** verbatim
    (`TextStyle(...)`, `LinearGradient(...)`, `BorderRadius.all(Radius.circular(16))`).
- **`provenance`** — `variable` (read from a token) → emitted plain; `inferred`
  (screenshot / clustered type scale) → emitted with `// confirm:`; `todo`
  (Figma couldn't answer) → the field inherits `NeoSduiTheme.fallback()` and is
  listed under `// TODO(theme):`.
- **`roleUsage`** — as you classify each wire block, record every `tone:`,
  `emphasis:`, `icon:` role it names. This is the shared registry the role-drift
  lint checks: a `tone:brand` here with no `accents.brand` in the ledger is a
  blocking lint issue.

## 3. Compile — the terminal step

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
  page-count majority (the escape hatch, §4) — every other page's differing look
  becomes an override.

## 4. Hybrid conflict prompt (the one human call)

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

## 5. Hand off

Give the user the emitted `theme.dart` (base + overrides) plus the coverage
report, flagging every `// confirm:` (inferred) and `// TODO(theme):` (no data)
for review. The theme is pasted into the app; the app decides which
`NeoSduiTheme` each `NeoSduiView` gets (route/guide → theme is app wiring, not
figwire's job).
