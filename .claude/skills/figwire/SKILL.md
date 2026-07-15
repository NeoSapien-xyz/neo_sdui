---
name: figwire
description: Use when turning any Figma selection — a page, frame, component, or node — into neo_sdui-compliant wire JSON for this repo: a figma.com link/selection, node id, or pasted screenshot that must become a `{version, blocks, views}` document (destined for Firebase Remote Config). The MCP guide is just one example; this is the general Figma→wire path. The inverse of `neofig` (which writes Flutter look); figwire writes wire semantics. Not for the neo app's widget code, and not for pushing to Firebase.
---

# figwire — Figma selection → neo_sdui wire JSON

Turn a Figma selection — a page, frame, component, or node — into a neo_sdui wire document. The
MCP guide is one example, not the boundary: any selection destined for a neo_sdui screen is in
scope. The wire carries **semantics only**
(structure + text + role tags) — never look. From the *same* Figma read, figwire also produces an
optional **look projection**: a role ledger that accumulates across pages and compiles to a paste-in
`NeoSduiTheme` (a base theme + per-page `copyWith` overrides). The wire goes to Remote Config; the
theme goes to the app. `neofig` owns look→widget *code*; figwire owns both the wire and the theme —
two projections of one read (see `references/theme-extract.md`).

The finished output is a **deliverable folder** — the wire doc plus its exported image assets, laid
out to mirror the CDN and staged (gitignored) for the user to review and upload as-is. Exporting
assets does not break the Iron Rule: the wire still carries only the image URL string, never the
bytes (see `references/deliverables-and-assets.md`).

## Status — this skill is young, and meant to grow

This is a first working cut, proven end-to-end against a hand-written sample but not yet against a
live Figma selection at volume. Treat it as a living tool: **try it, test it, break it, build it back
better.** Every real Figma selection you run through it will expose a rough edge — a region the
classifier mis-buckets, a field shape the contract missed, a coverage report that's noisier than it
should be.
That's expected and welcome. When something breaks or annoys you: fix the reference it lives in
(`wire-contract.md`, `accent-tones.md`, `ingestion.md`, `verify-output.md`) or the package tools, add
a test that pins the fix, and re-run the gates. The contract, the accent map, and the classification
guidance are all meant to sharpen with use — this file is a starting point, not a finished spec.

Known next steps to grow into: a live-Figma dry-run at volume, the `neo:` annotation convention for
deterministic classification, tuning the coverage-report format and low-confidence threshold, and
(later) a Firebase Remote Config push. See the plan
(`docs/plans/2026-07-13-001-feat-figma-to-neo-wire-generator-plan.md`) for the full deferred list.

## The Iron Rule

```
NO #hex, NO px, NO fontSize/fontFamily/fontWeight, NO gradient stops, NO shadows,
NO spacing numbers — EVER — on the wire.
```

The one visual signal you may read is the **accent green**, and only to set `tone:"accent"` (see
`references/accent-tones.md`). Everything else about look lives in the client-owned `NeoSduiTheme`.
If you are about to write a color/font/gradient into the JSON, stop — you are breaking the contract
the whole package depends on.

## When to use

- A figma.com link/selection or node id destined for a neo_sdui screen is in scope for this repo.
- A designer handed a screenshot of a screen, frame, or component to transcribe into a wire document.

**Not for:** the neo app's Dart widgets (that's `neofig`), pushing JSON to Firebase Remote Config
(out of scope — figwire writes a reviewable deliverable folder), or inventing look.

## Workflow

### 1. Ingest (see `references/ingestion.md`)

MCP-first, degrade to a pasted/exported screenshot only when the MCP is unavailable or a call
fails. Get the `get_metadata` node inventory first (it is the coverage denominator), the screenshot
for visual truth, and exact text from `get_design_context`/REST for any `code`/URL block. Handle the
`FIGMA_TOKEN` via env var only, never logged.

A guide-family is usually **several frames** (a hub + per-client guides + per-tab frames); collect
them all. Only the main thread can read the Figma MCP — subagents cannot auth it, so pull every
frame/screenshot/asset yourself and hand agents the files. See
`references/deliverables-and-assets.md` for how frames collapse into blocks/views.

### 2. Classify + pull text (see `references/wire-contract.md`)

Map each region of the page to exactly **one of the 14 block types**. A region that fits none gets
reported, not force-fit into a wrapper. Pull each block's text as `string-or-runs`. Tag accent text
`tone:"accent"` per `references/accent-tones.md`. Do not invent a block type — off-roster types are
a hard error.

**Look projection (optional theme).** As you classify, record each block's `tone`/`emphasis`/`icon`
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

Never write an ungated document. In order: (a) run the hard validate gate
(`check_wire_test.dart` — fails on off-roster types / structural errors); (b) compute the coverage
report against the independent inventory (downgraded on the screenshot path); (c) render the
structural preview PNG (`render_wire_test.dart`); (d) secret-scan the extracted text. If the run
accumulated a theme, also run the theme gates — compile + role-drift lint + round-trip render (see
`references/verify-output.md` §6).

### 6. Write the deliverable

Only after the validate gate passes: write the wire to `deliverables/<family>/<family>.json` and the
exported images to `deliverables/<family>/assets/` (gitignored, CDN-mirroring). Show the coverage
report, preview path, the asset `HAVE`/`MISSING` manifest, and any low-confidence / secret flags for
sign-off. No Firebase push. See `references/deliverables-and-assets.md`.

If a theme was accumulated, run the terminal compile once at the end and hand the user the base
`NeoSduiTheme` + per-page `copyWith` overrides + the coverage report, resolving any conflict roles via
the hybrid prompt (`references/theme-extract.md`). The theme is pasted into the app; figwire does not
wire route/guide → theme selection (that is app-side).

## References

- `references/wire-contract.md` — the 14 block types, their fields, the string-or-runs shape, enums,
  action grammar, the forbidden-on-wire list, and a minimal document.
- `references/accent-tones.md` — the accent-green → `tone:"accent"` signal (and never emit the hex).
- `references/ingestion.md` — MCP call order, REST, screenshot degrade, token handling.
- `references/verify-output.md` — the four wire gates, the theme gates (§6), and the write step, with the exact commands.
- `references/theme-extract.md` — the look projection: token-first extraction, the role-ledger format, the terminal compile, and the hybrid conflict prompt.
- `references/deliverables-and-assets.md` — the gitignored `deliverables/<family>/` output scheme, one-JSON-per-family + when to split, multi-frame collapse (tabs/components), and Figma asset export + role-based grouping.

Package tools these call (in `packages/neo_sdui/`):
- `test/tools/check_wire_test.dart` — `NEO_WIRE_JSON=<path> fvm flutter test test/tools/check_wire_test.dart` → structural + vocabulary gate.
- `test/tools/render_wire_test.dart` — `NEO_WIRE_JSON=<path> [NEO_THEME_LEDGER=<ledger>] [NEO_THEME_BASE_PAGE=<page>] fvm flutter test --update-goldens test/tools/render_wire_test.dart` → `.render/preview.png` (optionally under the compiled theme; pass the **same** `NEO_THEME_BASE_PAGE` you compiled with, or the preview renders a different base than the theme you hand off).
- `test/tools/compile_theme_test.dart` — `NEO_THEME_LEDGER=<ledger> [NEO_THEME_OUT=<theme.dart>] [NEO_THEME_BASE_PAGE=<page>] fvm flutter test test/tools/compile_theme_test.dart` → paste-in `NeoSduiTheme` + coverage report + role-drift lint (`NEO_THEME_BASE_PAGE` pins that page's look as the base).
