# Verify and output — the "verify, don't trust" tail

Never write a document you haven't gated. Silent element drop / mis-bucketing is the failure mode
this skill exists to prevent. Run all four, in order, then write.

Assume the assembled document is at a temp path `$WIRE` (e.g. `/tmp/figwire/<page>.json`).
Run the package tools from `packages/neo_sdui/`.

## 1. Validate (hard gate)

```bash
NEO_WIRE_JSON="$WIRE" fvm flutter test test/tools/check_wire_test.dart
```

- Runs `validateDocument` (structural) **and** `validateWireVocabulary` (14-type allowlist +
  required fields).
- **Fails (non-zero) on any blocking issue** — a structural error, an off-roster `type`, or a
  non-map block. On failure, surface the printed `STRUCT`/`VOCAB` lines and **do not write** the
  document; fix the classification and re-run.
- **Warnings** (missing required fields, printed as `[warn]`) do not fail — the renderer degrades
  those to empty/collapsed. List them for the human but proceed.

## 2. Coverage report (warn + continue)

Compare the emit against the **independent inventory**:

- **MCP/REST path:** the "seen" set is every visible text node from `get_metadata` (or REST
  `characters`). Report `seen N → emitted M`, and **name every dropped and ambiguous node**. This is
  the real anti-drop check.
- **Screenshot-only path:** "seen" comes from the same vision pass that emitted, so it cannot detect
  a region the model never perceived. Mark the coverage figure **low-confidence** and state that the
  anti-drop guarantee is **downgraded** on this path — never present it as full coverage.
- Also flag every `code`/URL block whose text was vision-inferred (low-confidence) for human verify.

This never blocks output — it is the human's eyeball list.

## 3. Structural render preview

```bash
NEO_WIRE_JSON="$WIRE" fvm flutter test --update-goldens test/tools/render_wire_test.dart
# writes packages/neo_sdui/.render/preview.png
```

Structural only — fallback fonts, network images render as placeholders. Enough to confirm block
presence, type, order, and nesting against the Figma screenshot; **not** pixel/font fidelity. Show
the human the PNG next to the screenshot.

## 4. Secret scan (before write)

Designer mock text is copied verbatim, so scan the extracted strings for secret-like patterns before
writing — API keys, bearer tokens, `sk-`/`figd_`/`AKIA`-style prefixes, private/internal URLs.
Flag any hit for the human to confirm or redact. Re-affirm this gate before any future Firebase
Remote Config push.

## 5. Write

Only after 1 passes (no blocking issues): write the wire `.json` to the repo (a `docs/` or
config location the user names) for review and commit. Print the coverage report + preview path +
any low-confidence / secret flags so the human can sign off. Do **not** push to Firebase — that is
out of scope.

## 6. Theme compile + verify (only if the run also built a look projection)

When the run accumulated a role ledger (`theme-extract.md`), the theme has its own gates — it fails by
rendering *wrong*, not by vanishing, so the wire gates can't catch it. Run these on the final ledger:

```bash
# Compile + role-drift lint (fails if a wire role has no theme slot):
NEO_THEME_LEDGER=<ledger.json> NEO_THEME_OUT=<theme.dart> \
  fvm flutter test test/tools/compile_theme_test.dart

# Confirm the emitted theme actually compiles:
fvm flutter analyze <theme.dart>

# Round-trip render an accumulated wire UNDER the compiled theme, to eyeball vs the Figma screenshot:
NEO_WIRE_JSON=<wire.json> NEO_THEME_LEDGER=<ledger.json> \
  fvm flutter test --update-goldens test/tools/render_wire_test.dart   # writes .render/preview.png
```

The compile prints the paste-in `NeoSduiTheme` (base + per-page `copyWith`) and a coverage report;
surface every `// confirm:` (inferred) and `// TODO(theme):` (no data) for the human, and resolve the
compile's **conflict roles** via the hybrid prompt in `theme-extract.md` before finalizing.
