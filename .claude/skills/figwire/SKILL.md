---
name: figwire
description: Use when turning a Figma page/frame for a neo_sdui guide (e.g. the MCP guide) into neo_sdui-compliant wire JSON for this repo — a figma.com page URL, node id, or pasted screenshot that must become a `{version, blocks, views}` document for Firebase Remote Config. The inverse of `neofig` (which writes Flutter look); figwire writes wire semantics. Not for the neo app's widget code, and not for pushing to Firebase.
---

# figwire — Figma page → neo_sdui wire JSON

Turn one Figma page into one neo_sdui wire document. The wire carries **semantics only**
(structure + text + role tags) — never look. `neofig` owns the look (colors, fonts, the theme);
figwire owns the wire. They are mirror halves of the same pipeline.

## Status — this skill is young, and meant to grow

This is a first working cut, proven end-to-end against a hand-written sample but not yet against a
live Figma page at volume. Treat it as a living tool: **try it, test it, break it, build it back
better.** Every real guide page you run through it will expose a rough edge — a region the classifier
mis-buckets, a field shape the contract missed, a coverage report that's noisier than it should be.
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

- A figma.com page URL or node id for a neo guide is in scope for this repo (`neo_sdui`).
- A designer handed a screenshot of a guide page to transcribe into a wire document.

**Not for:** the neo app's Dart widgets (that's `neofig`), pushing JSON to Firebase Remote Config
(out of scope — figwire writes a reviewable file), or inventing look.

## Workflow

### 1. Ingest (see `references/ingestion.md`)

MCP-first, degrade to a pasted/exported screenshot. Get the `get_metadata` node inventory first
(it is the coverage denominator), the screenshot for visual truth, and exact text from
`get_design_context`/REST for any `code`/URL block. The Figma seat is tightly capped — treat the
screenshot as the everyday path. Handle the `FIGMA_TOKEN` via env var only, never logged.

### 2. Classify + pull text (see `references/wire-contract.md`)

Map each region of the page to exactly **one of the 14 block types**. A region that fits none gets
reported, not force-fit into a wrapper. Pull each block's text as `string-or-runs`. Tag accent text
`tone:"accent"` per `references/accent-tones.md`. Do not invent a block type — off-roster types are
a hard error.

### 3. Assemble

Build the whole-page `{version, blocks, views}` in reading order. Put navigable sub-screens
(FAQ, detail screens) in `views` with `present:"sheet"|"screen"` and point `card`/`cta` `action`s at
them. **Navigation targets cannot be inferred** — emit `"action": "TODO:<hint>"` for every tappable
element and let the human wire the real `route:`/`screen:`/`sheet:` once all pages exist.

### 4. Verify (see `references/verify-output.md`)

Never write an ungated document. In order: (a) run the hard validate gate
(`check_wire_test.dart` — fails on off-roster types / structural errors); (b) compute the coverage
report against the independent inventory (downgraded on the screenshot path); (c) render the
structural preview PNG (`render_wire_test.dart`); (d) secret-scan the extracted text.

### 5. Write

Only after the validate gate passes: write the wire `.json` to a repo location the user names, and
show the coverage report, preview path, and any low-confidence / secret flags for sign-off. No
Firebase push.

## References

- `references/wire-contract.md` — the 14 block types, their fields, the string-or-runs shape, enums,
  action grammar, the forbidden-on-wire list, and a minimal document.
- `references/accent-tones.md` — the accent-green → `tone:"accent"` signal (and never emit the hex).
- `references/ingestion.md` — MCP call order, REST, screenshot degrade, token handling, seat limits.
- `references/verify-output.md` — the four verify gates and the write step, with the exact commands.

Package tools these call (in `packages/neo_sdui/`):
- `test/tools/check_wire_test.dart` — `NEO_WIRE_JSON=<path> fvm flutter test test/tools/check_wire_test.dart` → structural + vocabulary gate.
- `test/tools/render_wire_test.dart` — `NEO_WIRE_JSON=<path> fvm flutter test --update-goldens test/tools/render_wire_test.dart` → `.render/preview.png`.
