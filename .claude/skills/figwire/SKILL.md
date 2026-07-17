---
name: figwire
description: Use when a Figma selection — a figma.com link, node id, page, frame, component, or a pasted screenshot — has to become neo_sdui wire JSON in this repo, or when an existing wire or the NeoSduiTheme it renders under must change to match a design. Also use when a rendered neo_sdui screen looks wrong — color, type, gradient, icon, spacing, missing block — and the fix belongs in the wire or the theme rather than in the neo app's Flutter widgets (that is `neofig`).
---

# figwire — Figma selection → neo_sdui wire JSON

Turn a Figma selection — a page, frame, component, or node — into a neo_sdui wire document. The
MCP guide is one example, not the boundary: any selection destined for a neo_sdui screen is in
scope. The wire carries **semantics only**
(structure + text + role tags) — never look. From the *same* Figma read, figwire produces a second,
**non-optional** projection: a **look projection** — a role ledger that accumulates across pages and
compiles to a paste-in `NeoSduiTheme` (a base theme + per-page `copyWith` overrides). The wire goes
to Remote Config; the theme goes to the app. `neofig` owns look→widget *code*; figwire owns both the
wire and the theme — two projections of one read (see `references/theme-extract.md`).

**A wire without its theme is not a deliverable.** The look does not render "close enough" from
`NeoSduiTheme.fallback()` — it renders a different screen. Treating the theme as optional is how a
guide reached a device with a system font, no gradients, and no icons.

The finished output is a **deliverable folder** — the wire doc plus its exported image assets, laid
out to mirror the CDN and staged (gitignored) for the user to review and upload as-is. Exporting
assets does not break the Iron Rule: the wire still carries only the image URL string, never the
bytes (see `references/deliverables-and-assets.md`).

**Done is the screen matching the design on a device — not the gates passing.** Every gate here is
structural: none of them can see a value you invented sitting in a slot that exists. A run ends when
the user confirms parity, or with a written list of what still differs and why.

## The Iron Rule

```
NO #hex, NO px, NO fontSize/fontFamily/fontWeight, NO gradient stops, NO shadows,
NO spacing numbers — EVER — on the wire.
```

You read a color to **choose a role name**, never to emit a value. The wire may name **any** accent
role the theme declares: `tone:"<name>"` → `theme.accents['<name>']`, an open map keyed by prefix
(`accent`/`critical`/`warning` are built in — `accentFor` checks the named entry first). A yellow
title is `tone:"warning"`, not `#FFC107`; a hue with no role yet → declare `accents.<name>` in the
ledger and name it on the wire (see `references/accent-tones.md`). Everything else about look lives
in the client-owned `NeoSduiTheme`. If you are about to write a color/font/gradient into the JSON,
stop — you are breaking the contract the whole package depends on.

## When to use

- A figma.com link/selection or node id destined for a neo_sdui screen is in scope for this repo.
- A designer handed a screenshot of a screen, frame, or component to transcribe into a wire document.

**Not for:** the neo app's Dart widgets (that's `neofig`), pushing JSON to Firebase Remote Config
(out of scope — figwire writes a reviewable deliverable folder), or inventing look.

## Propagation + host — figwire doesn't push it; it still owns knowing what happens to it

- **Wire** changes reach the device only on an RC republish, and RC caches **1 day** in release — an
  unchanged screen right after a push is a cache, not a defect. **Package/app** changes (a theme
  paste, a block edit) land on a rebuild instead. Name which lever a fix needs when you hand it over.
- A pushed sub-view's app-bar title is `views.<id>.title` (`NeoView.title`, `lib/src/model/view.dart:23`).
- Chrome is the app's, not the wire's: the transparent+frosted precedent is
  `neo/lib/view/screens/profile/how_to_screen.dart:44-58` — cite it, don't re-derive it. No sibling
  screen of the family → "no precedent — chrome is unverified" in the handoff, not silence.

## Workflow

### 1. Ingest (see `references/ingestion.md`)

**The two projections do not share an ingest** — read `references/ingestion.md` §matrix before the
first call:

| projection | first call | why |
|---|---|---|
| **wire** (semantics) | `get_metadata` | the *independent* coverage denominator — `get_design_context` is the same pass that emits, so it cannot audit itself |
| **theme** (look) | `get_design_context` (+ `get_variable_defs` for token-bound roles) | the **only** calls carrying type/fill/effect. `get_metadata` returns `id/name/type/x/y/w/h` — no fills, no typography, no effects |

**Reading `get_metadata` and then writing a look value is the defect that matrix exists to prevent.**
`get_metadata` returns no fills, no type, no effects — so a look value written after reading it came
from a screenshot or from your head. It shipped a theme whose `body` was `fontSize: 16`, a size that
appears **nowhere** in the design, and whose `subtitle` was 12/1.2 where the node says 13/1.3846. The
screenshot is visual truth for *classification and accent detection*, never for a number; every role
it feeds is `provenance:"inferred"`, which **fails the compile**. Exact text for any `code`/URL block
comes from `get_design_context`/REST. Handle the `FIGMA_TOKEN` via env var only, never logged.

A guide-family is usually **several frames** (a hub + per-client guides + per-tab frames); collect
them all. Only the main thread can read the Figma MCP — subagents cannot auth it, so pull every
frame/screenshot/asset yourself and hand agents the files. See
`references/deliverables-and-assets.md` for how frames collapse into blocks/views.

### 2. Classify + pull text (see `references/wire-contract.md`)

Map each region of the page to exactly **one of the 14 block types**. A region that fits none gets
reported, not force-fit into a wrapper. Pull each block's text as `string-or-runs`. Tag a
deliberately-hued text with the **role name** its hue means — `tone:"accent"` for the brand green,
`tone:"critical"`, `tone:"warning"`, or any `accents.<name>` the ledger declares — per
`references/accent-tones.md`. Do not invent a block type — off-roster types are a hard error.

**Look projection.** As you classify, record each block's `tone`/`emphasis`/`icon`
role into the ledger's `roleUsage`, and append the page's look observations (colors, type, gradients)
to the role ledger — the *complement* of the wire, per `references/theme-extract.md`. Look values
never ride the wire; they only go to the ledger.

### 3. Assemble

Build **one** `{version, blocks, views}` doc for the whole guide-family (not one per page): root
`blocks` = the hub screen, `views` = every sub-screen (`present:"sheet"|"screen"`). Define a shared
tail (FAQ / troubleshooting stamped on every screen) as ONE view and point each screen's `card`/`cta`
`action` at it by name — never re-embed it. Collapse per-tab frames into one `tabs` block.
**Navigation targets cannot be inferred** — emit `"action": "TODO:<hint>"` for every tappable
element; the human wires the real `route:`/`screen:`/`sheet:` on the final call.
See `references/deliverables-and-assets.md` for one-doc-per-family, multi-frame collapse, and when to split.

### 4. Export assets (see `references/deliverables-and-assets.md`)

Export each image node from Figma (`download_assets`, @3x) into the guide's `assets/`, grouped by
role — flat for the shared hub images, per-client subfolders for the many step screenshots. Three
hard rules:
- **Keep the cropped render.** Use the `download_assets` `export` (the node as displayed — cropped),
  **never** the `rawImages` source (the full, uncropped image). Two variants of one node → keep the cropped.
- **Identical names, no renaming.** The filename + folder path is the same in `deliverables/`, on the
  CDN, and in the wire `url`. The user uploads the family folder to the CDN as-is.
- **CDN url on the wire, never local.** Every wire `url` is the full `https://<cdn>/…` path mirroring
  the deliverables layout — never a local or relative path.

If a hero has text baked in, emit `media` only (no duplicate `header`). Only the main thread can read
Figma; pull the assets yourself.

### 5. Verify (see `references/verify-output.md`)

Never write an ungated document. `references/verify-output.md` §A is the ladder and this is its
order — **highest yield first**, because the last run's largest bucket was a fabricated value sitting
in a slot that exists, and only the first gate can see that:

```bash
# 1. The look as data — the ~26% bucket. No widget, no pump, no font file.
NEO_THEME_LEDGER=<ledger> fvm flutter test test/authoring/theme_values_test.dart
# 2. Registry + contract drift, baked type constants.
fvm flutter test test/authoring/
# 3. The wire itself — off-roster types, structural errors.
NEO_WIRE_JSON=<wire> fvm flutter test test/tools/check_wire_test.dart
# 4. The theme compile — fails on any `provenance:"inferred"` role.
NEO_THEME_LEDGER=<ledger> fvm flutter test test/tools/compile_theme_test.dart
```

Then the non-gates: the coverage report against the independent inventory (downgraded on the
screenshot path) and a secret-scan of the extracted text. `render_wire_test.dart` is a **picture, not
a check** (`references/verify-output.md` §B).

**A theme gate is not conditional.** "If the run accumulated a theme" was the old framing and it is
how a wire reached a device under `fallback()`. Every run accumulates a theme (see the header).

None of them can tell you the design is *pretty*. They tell you a number was fabricated, a family
was bound as a dead string, a gradient lost its handles, a theme field has no ledger slot, or the
contract has drifted from the blocks. That is the floor, not parity — see the header.

### 6. Write the deliverable

Only after the validate gate passes: write the wire to `deliverables/<family>/<family>.json` and the
exported images to `deliverables/<family>/assets/` (gitignored, CDN-mirroring). Show the coverage
report, preview path, the asset `HAVE`/`MISSING` manifest, and any low-confidence / secret flags for
sign-off. No Firebase push. See `references/deliverables-and-assets.md`.

If a theme was accumulated, run the terminal compile once at the end and hand the user the base
`NeoSduiTheme` + per-page `copyWith` overrides + the coverage report, resolving any conflict roles via
the hybrid prompt (`references/theme-extract.md`). The theme is pasted into the app; figwire does not
wire route/guide → theme selection (that is app-side).

The loop does not end here — a written deliverable is not a matching screen. Name the lever each
piece needs (republish / rebuild, above) and close on parity or on a written diff list.

## References

- `references/wire-contract.md` — the 14 block types, their fields, the string-or-runs shape, enums,
  action grammar, the forbidden-on-wire list, and a minimal document.
- `references/accent-tones.md` — reading a color to choose a role *name*: the brand green → `tone:"accent"`, and any other deliberate hue → `critical`/`warning`/a ledger-declared `accents.<name>` (never the hex).
- `references/ingestion.md` — MCP call order, REST, screenshot degrade, token handling.
- `references/verify-output.md` — §A the gate ladder (what fails the run), §B the artifacts that *cannot* fail, §C what nothing here can see, and the write step, with the exact commands.
- `references/theme-extract.md` — the look projection: token-first extraction, the role-ledger format, the terminal compile, and the hybrid conflict prompt.
- `references/deliverables-and-assets.md` — the gitignored `deliverables/<family>/` output scheme, one-JSON-per-family + when to split, multi-frame collapse (tabs/components), and Figma asset export + role-based grouping.

Package tools these call (in `packages/neo_sdui/`):
- `test/tools/check_wire_test.dart` — `NEO_WIRE_JSON=<path> fvm flutter test test/tools/check_wire_test.dart` → structural + vocabulary gate.
- `test/tools/render_wire_test.dart` — `NEO_WIRE_JSON=<path> [NEO_THEME_LEDGER=<ledger>] [NEO_THEME_BASE_PAGE=<page>] fvm flutter test --update-goldens test/tools/render_wire_test.dart` → `.render/preview.png`. A **picture generator, not a check**: `--update-goldens` makes `matchesGoldenFile` write and pass unconditionally, and the type scale renders at fallback. Trust it for block presence, order, nesting, palette — nothing else (`verify-output.md` §B). Pass the **same** `NEO_THEME_BASE_PAGE` you compiled with, or it reconciles a different base than the theme you hand off.
- `test/authoring/theme_values_test.dart` — `NEO_THEME_LEDGER=<ledger> fvm flutter test test/authoring/theme_values_test.dart` → the look asserted as data: family bound (never a bare `fontFamily:`), gradients carry `begin`/`end`.
- `test/golden/` — `fvm flutter test test/golden/` → **no flag, so these can actually fail** (the PNGs are committed). A regression alarm, not a parity check, and narrower than it looks: every golden is 2400×1800 = the **default 800×600 surface at DPR 3**, so the 390-wide guide sits centered in an 800-wide window and is clipped to ~600 logical px tall — a tall view is captured as a middle slice — and the type renders at the fallback font. It tells you *something moved*, never *it matches figma*. Regenerate only when you intend the look to change (`fvm flutter test --update-goldens test/golden/`).
- `test/tools/compile_theme_test.dart` — `NEO_THEME_LEDGER=<ledger> [NEO_THEME_OUT=<theme.dart>] [NEO_THEME_BASE_PAGE=<page>] fvm flutter test test/tools/compile_theme_test.dart` → paste-in `NeoSduiTheme` + coverage report + role-drift lint (`NEO_THEME_BASE_PAGE` pins that page's look as the base).
