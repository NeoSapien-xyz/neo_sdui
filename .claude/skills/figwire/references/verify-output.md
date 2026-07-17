# Verify — the gate ladder, and what each gate is blind to

**Every gate here checks an artifact against itself. None checks it against Figma.** The suite passes
green on a wire + theme compiled from a *different Figma file*. Measured last run: **0 of ~53 device
defects blocked**, ~5 reachable as an advisory. A green check beside a broken screen is worse than no
check — so each gate states what it cannot see.

**Green ≠ parity; the loop does not end at "write".** Done = the built screen matches the design, or
the handoff names an accepted delta list. Wire at `$WIRE`, ledger at `$LEDGER`. Run from `packages/neo_sdui/`.

[A. Gates (these fail the run)](#a-gates--these-fail-the-run-run-all-then-write) ·
[B. Human artifacts (these cannot fail)](#b-artifacts-for-the-human--these-cannot-fail-never-report-them-as-gates) ·
[C. What nothing here can see](#c-what-nothing-here-can-see) · [Write, then look](#write-then-look)

## A. Gates — these fail the run. Run all, then write.

**1. Theme values — the look is data (highest yield).**
`NEO_THEME_LEDGER=$LEDGER fvm flutter test test/authoring/theme_values_test.dart`
The compiled theme asserted as **data** — no widget, no pump, no font file: family bound (never a bare
`fontFamily:` string, which resolves to the system fallback), gradients carry `begin`/`end`
(`LinearGradient` defaults to **horizontal**). The last run's largest bucket — **~26% of defects were a
wrong value in a slot that already existed** — is this shape, and nothing was looking.
*Blind to:* whether a plausible value is the *designed* value. `fontSize: 22` for Figma's 24 passes.
This file asserts only what the ledger can **prove**. A wrong-but-plausible number is `provenance`'s
job (gate 2), not a regex's — a detector here once guessed at it from shape and was wrong.

**2. Provenance — the compile fails on guesses.**
`NEO_THEME_LEDGER=$LEDGER NEO_THEME_OUT=<theme.dart> [NEO_THEME_BASE_PAGE=<page>] fvm flutter test test/tools/compile_theme_test.dart`
Compiles the paste-in `NeoSduiTheme` (base + per-page `copyWith`), lints role drift, and **exits
non-zero on any `provenance:"inferred"` role** — `variable` and `measured` both pass. Override with
`NEO_THEME_ALLOW_INFERRED=1` only while saying so in the handoff. Surface every `// confirm:` and
`// TODO(theme):`; resolve conflict roles per `theme-extract.md`. Never strip a marker.
**If this gate fires on most of your roles, suspect your grading before you re-read Figma** — the
last theme graded 26 of 29 `inferred` because the file exposes only two variables, so the waiver
became mandatory and all 26 markers got stripped as noise. Read-vs-invented, that ledger was 25
`measured` and **2** real guesses (`theme-extract.md` §3).
*Blind to:* the value behind a passing role — provenance says where a number came from, not if it's
right. `fontSize: 22` recorded as `measured` off the wrong node passes.

**3. The theme compiles.** `fvm flutter analyze <theme.dart>` — `textStyle`/`gradient` roles ride the
emit as verbatim literals, so this is the only thing type-checking them.
*Blind to every value* — any wrong number is still valid Dart. Never count `analyze` as look verification.

**4. Wire validate.** `NEO_WIRE_JSON=$WIRE fvm flutter test test/tools/check_wire_test.dart`
`validateDocument` + `validateWireVocabulary`: fails on a structural error, an off-roster `type`, or a
non-map block — surface the printed `STRUCT`/`VOCAB` lines and **do not write**. Missing required
fields print `[warn]` and do not fail (the renderer degrades them); list them for the human.
*Blind to fidelity.* `_text()` accepts a non-empty String *or* List, so the green callout box — `title`
as one flat toned string vs. the run split `[{"text":"If "},{"text":"from NeoSapien","tone":"accent"}]`
— passes **identically both ways**. It cannot tell the bug from the fix.

**5. Reference drift.** `fvm flutter test test/authoring/` — `contract_drift_test.dart` (every
`stringOr('x')`/`nodeList('x')` literal in `blocks/` appears in `wire-contract.md`) and
`role_slots_complete_test.dart` (every `NeoSduiTheme` ctor param has a `kRoleSlots` entry or an explicit
absent-list row). They stop the references going stale against the code — the reason `NeoView.title` sat
unemittable for a week after the model grew it.
*Blind to:* whether a documented field was used correctly.

**6. Asset URL probe.** `curl -s -o /dev/null -w '%{http_code}'` one real wire URL → expect 200
(`deliverables-and-assets.md`). A **gate**, not a sanity check: the base was derived from the local
folder twice and 403'd both times.

**7. Secret scan.** Mock text is copied verbatim — scan the extracted strings for `sk-`/`figd_`/`AKIA`
prefixes, bearer tokens, private/internal URLs. Re-affirm before any Remote Config push.
*Blind to pixels*, and the asset gate beside it reads filenames. A redacted terminal screenshot reached
a public CDN straight between them: the one asset carrying PII carried it exactly where neither gate is
defined to look. Eyeball every PNG (`deliverables-and-assets.md`) — nothing else is standing there.

## B. Artifacts for the human — these cannot fail. Never report them as gates.

**Coverage report.** MCP/REST path: "seen" = every visible text node from `get_metadata` (or REST
`characters`); report `seen N → emitted M` and **name every dropped and ambiguous node**.
Screenshot-only path: "seen" comes from the same vision pass that emitted — **circular**, blind to a
region the model never perceived; mark it low-confidence, state that the anti-drop guarantee is
downgraded, never present it as coverage. Flag every vision-inferred `code`/URL.

**Preview PNG — a screenshot generator, not a check.**

```bash
NEO_WIRE_JSON=$WIRE [NEO_THEME_LEDGER=$LEDGER] [NEO_THEME_BASE_PAGE=<page>] \
  fvm flutter test --update-goldens test/tools/render_wire_test.dart   # writes .render/preview.png
```

`--update-goldens` makes `matchesGoldenFile` **write and pass unconditionally** — this command has no
failure mode, by construction. That is fine; its job is a picture. Calling it a check is not. Three
blindnesses, and the third is the one that cost the day:

1. Fallback fonts; network images render as their error placeholder.
2. `--update-goldens` (above).
3. **It never renders the compiled type scale.** `kRoleSlots` registers `title`/`subtitle`/`body`/
   `caption`/`mono` as `ValueKind.textStyle` with **no `live` painter** (`theme_compile.dart:97-101`),
   so `buildBaseTheme`'s `live != null` guard (`:159-160`) drops them and they stay at
   `NeoSduiTheme.fallback()` — title 22, body 15 (`neo_sdui_theme.dart:327-329`). The preview a human
   was told to eyeball for parity was **structurally incapable of showing a font-size bug.**

Trust it for block presence, type, order, nesting and palette. Nothing else. Pass the **same**
`NEO_THEME_BASE_PAGE` you compiled with, or it reconciles a different base than the theme you hand off.

**Regression goldens are a different thing, and a real gate:** `fvm flutter test test/golden/`,
**without** the flag. Regenerating is a separate deliberate command — `fvm flutter test
--update-goldens test/golden/` — run only when you intend the look to change, and say so.

## C. What nothing here can see

- **~9% of the last run's defects are irreducible design taste** — "doesn't look neumorphic", "the
  noise is absent", "the spacing is unprecedented", "looks bad overall". No gate catches these; a human
  looking at a phone is the instrument. Do not promise a check that makes design review disappear —
  make the review **cheap**: an RC republish reaches a foregrounded app near-instantly (`SKILL.md`),
  so the loop is already short. Hand over something to look at rather than a reason to wait.
- **Block rendering code.** The theme can carry `stepCardColor`; it cannot carry "the pill presses into
  the groove". That is `neo_sdui` block code and app host code — not figwire's to gate, and the handoff
  must say so rather than let "theme handed off" imply the look is covered.

## Write, then look

After A passes: write the wire `.json` where the user names it; print the coverage report, preview path,
every `// confirm:` role, secret/asset flags, the required add-on manifest, and the delta list. No
Firebase push — out of scope. **Then look at the built screen against the design.** Parity, or a named
accepted delta, ends the loop. The gates are only its cheap part.
