# Ideation — a Figma → neo_sdui wire-JSON generator skill

**Date:** 2026-07-13
**Subject:** A Claude skill that takes a Figma page/frame selection and emits neo_sdui-compliant wire JSON, ready to drop into Firebase Remote Config. Fed a Figma link selection; outputs the document.
**Mode:** repo-grounded (the JSON must satisfy *this* package's wire contract).
**Verdict up front:** Good idea, and unusually tractable — but for a non-obvious reason. Build it. The MVP is a *classify-then-verify* skill, not a Figma-tree exporter. One decision (build a review/preview loop) separates "ships confident garbage" from "actually usable."

---

## Why this is more tractable than generic "Figma → code"

The thing that makes design-to-code hard is extracting *look* — colors, fonts, spacing, gradients, pixel fidelity — from arbitrary layers. **The neo_sdui wire forbids all of that.** The wire carries semantics only: `type` + content + role enums (`tone`/`emphasis`/`shape`/`variant`) + URLs + action strings. No hex, no px, no `fontSize`, no gradient stops — every pixel lives in the client-owned theme (`NeoSduiTheme`).

So the skill's job shrinks to: **structure + text + role hints**. It classifies each region into one of **14 core block types** and pulls the text. It never has to reproduce the gradient — it only tags `tone:"accent"` where a text is visually the accent color, and the theme paints it. The invariant that made the package resilient (semantics-only wire) is the same invariant that makes *generation* feasible: a small fixed target space with no visual-fidelity burden.

That is the whole thesis: **this is a classification problem into a 14-symbol alphabet, not a rendering problem.**

## Grounding context

**The output contract (fixed vocabulary — the skill's target alphabet).** Core types: `header, text, cta, callout, media, code, card, steps, faq, tabs, row, column, group, spacer`. Document = `{version:int, blocks:[...], views:{id:{present, blocks}}}`. Each block = `{type, ...content fields, requires?, fallback?}`. Cross-cutting shapes: string-or-runs (`"str"` or `["str", {text, tone:"accent"}]`) on `header.title`/`text.body`/`steps.items[].caption`; `tone ∈ {accent, critical}`; `emphasis ∈ {high, low, normal}`; action grammar `route:/sheet:/screen:/closeSheet/closeAll/https://`. Add-ons override `media` (video) and `code` (syntax) — no new type strings. Reads are all guarded, so a malformed field degrades rather than throws. Full contract lives in the code (`blocks/default_registry.dart`, per-block builders, `model/block_node.dart`).

**Reading Figma (grounded from Figma docs, July 2026):**
- Figma **MCP `get_design_context`** returns *React/Tailwind code*, not a clean tree — it has already made component decisions, so it fights a semantic-classification task.
- MCP **`get_metadata`** returns sparse XML (id/name/type/x/y/w/h) — good for *structure/reading-order*, drops text + styles.
- MCP **`get_screenshot`** returns a PNG — good for a *vision* classification pass.
- **REST `/v1/files/:key/nodes?ids=`** returns structured JSON: `children` (hierarchy), `layoutMode`/`itemSpacing`/`padding` (grouping signal), `characters` (the actual text), `style` (fontSize → heading-vs-body). Best *structured* classifier input; needs a personal access token; rate-limited per seat.
- **In this session the Figma MCP read tools are not connected** (they didn't resolve in the tool registry) — but they exist in the interactive Claude Code env where the skill would run. The skill must therefore degrade gracefully when the MCP is absent (fall back to REST token, or to a pasted screenshot).

**Firebase Remote Config (grounded):** JSON is stored as a *string* parameter (type is a console convenience; SDK always returns strings and the app casts). The real ceiling is a **1,000,000-char project-wide budget** across all parameter strings — dozens of per-screen docs are fine. Push generated JSON via the Admin/REST API rather than console paste; gate rollout with a condition (random-percentage) parameter. **Theme stays out of RC** — it's client-owned; only the wire ships.

**Prior-art lesson (Airbnb Ghost Platform, DivKit, SDUI-at-scale writeups):** everyone who does this separates *section/block data* from *layout*, keeps the vocabulary *small and versioned*, and — critically — **de-risks the layers→vocabulary step by constraining the input (naming conventions, Code Connect, component maps) rather than trusting geometry inference.** The dominant failure mode across UI-codegen evals is *silent element drop / mis-bucketing*, which is invisible unless you verify the output against the source.

### Topic axes (surfaces this ideation covers)
1. **Ingestion** — how the design gets in (MCP metadata+screenshot / REST tree / pasted export).
2. **Classification** — regions → the 14-type vocabulary + role tags. The hard core.
3. **Determinism aids** — naming/annotation/component-maps to convert inference into lookup.
4. **Verification loop** — validate + render-preview + diff, so drops are caught.
5. **Delivery** — file output → Firebase RC push, versioning, rollout, theme handoff.

---

## Surviving directions (ranked)

### A. Classify-then-verify skill (screenshot + metadata → JSON → validate → render preview) — **the spine, MVP**
The skill: (1) take a Figma node URL/selection; (2) pull `get_metadata` (structure/order) + `get_screenshot` (vision), optionally REST `/nodes` for exact `characters`; (3) the skill's own reasoning classifies each region into the 14-type vocabulary + role tags, pulling text; (4) emit JSON and run it through the package's existing `validateDocument`; (5) **render the JSON via the example harness to a preview PNG and show it next to the Figma screenshot** for human sign-off.
- **Why it survives:** matches how the field actually de-risks the classification step (verify against source). Vision + sparse structure is *enough* precisely because the target vocab is tiny and semantics-only. `validateDocument` already exists — free guardrail. Covers axes 1/2/4.
- **Basis:** `external:` UI-codegen failure taxonomy (silent element drop dominates) + `internal:` the wire's guarded-read/`validateDocument` design.
- **Effort:** M. The classification prompt + wiring MCP calls + reusing the render harness for preview.

### B. A `neo:` Figma annotation convention (deterministic classification for screens that matter) — **the reliability multiplier**
Designers tag frames with a semantic hint the skill keys off: a layer named `neo:steps`, `neo:card`, `neo:tone-accent`, `neo:action=screen:faq`. Where present, classification becomes a *lookup*, not inference; where absent, fall back to A's inference. Component-library variant → block-type maps (Code Connect-style) are the same idea for design-system-built screens.
- **Why it survives:** the single highest-leverage move in all the prior art — "naming is code." Converts the fuzzy step into a deterministic one for the screens you care about, without forcing it everywhere. Pairs with A rather than replacing it. Covers axis 3.
- **Basis:** `external:` Figma "naming is code" + Code Connect docs.
- **Effort:** S for the convention + parser; ongoing for designers to adopt.

### C. Round-trip preview as a hard gate (not just a nicety) — **the guardrail, part of MVP**
Not merely showing a preview — making "render the generated JSON and eyeball it against the frame" a required step in the skill, and surfacing a *coverage report*: "12 Figma text nodes seen → 11 emitted; 1 dropped (layer 'legal fine print')." This directly attacks silent-drop, the #1 documented failure.
- **Why it survives:** cheap (the package already renders; goldens already exist) and it's the difference between a toy and a tool. Folded into A but called out because it's the load-bearing quality mechanism. Covers axis 4.
- **Basis:** `internal:` existing golden/example render harness; `external:` failure taxonomy.
- **Effort:** S on top of A.

### D. Firebase RC publish + versioning (file-first, push optional) — **the delivery tail, deferrable**
Default output is a wire `.json` file the user reviews and commits. A `--publish` follow-on pushes it to RC via the Admin API as a JSON-typed parameter (one param per screen), optionally behind a random-percentage condition for staged rollout. Theme is explicitly *not* pushed.
- **Why it survives:** it's the user's stated end goal ("easily added to Firebase Remote Config"), but it's a thin, well-understood tail — decoupling it keeps the risky classification work independently shippable.
- **Basis:** `external:` RC parameters + automate-rc (Admin API) docs; 1M-char budget.
- **Effort:** S (Admin API call) — but only after A/C are trusted.

### E. Make the semantics-only invariant an explicit scope wall — **framing that kills scope creep**
Bake into the skill's own instructions that it MUST NOT extract colors/fonts/gradients/spacing into the JSON — it only maps `tone:"accent"` where text is visually the accent color, and leaves everything else to the theme. State the wire's forbidden list in the skill so it never "helpfully" puts a gradient stop on the wire.
- **Why it survives:** the most likely way this skill silently breaks the package is by violating the invariant ("the Figma has a gradient, so put it in the JSON"). Encoding the wall is nearly free and prevents a whole failure class. Cross-cuts every axis.
- **Basis:** `internal:` the wire invariant + the accent-text-gradient learning (`docs/solutions/architecture-patterns/accent-text-gradient-theme-owned.md`).
- **Effort:** XS (skill-prompt text).

---

## Rejected (with reasons — the point of ideation)

- **Naive REST-tree auto-walk → blocks (recurse every frame, no vision, no annotation).** This is exactly the exporter the prior art says fails: visual grouping ≠ semantic grouping, nested auto-layouts emit meaningless wrapper blocks (`row`/`column`/`group` spam), over-nesting. Produces structurally-valid, semantically-wrong JSON. The existing community "Figma→JSON" plugins already do this and stop short of semantics for this reason.
- **Extract the theme/colors/gradient from Figma into the JSON.** Violates the wire's core invariant. The package's entire resilience + per-guide-look model depends on look being client-owned. A tempting trap ("the design *has* the color") — reject hard. (This is why E exists.)
- **A Figma canvas plugin (in-Figma UI).** More surface than the goal needs; the skill + MCP/REST already reads the design. Revisit only if designers must self-serve tagging at scale — and even then B's naming convention is lighter.
- **A fine-tuned / dedicated classification model.** Overkill for a 14-symbol alphabet with no pixel decisions; an in-skill reasoning pass handles it. YAGNI.
- **One-shot "URL in → perfect JSON out, no review."** The documented failure is *silent* drop/mis-bucket. Without C's preview+coverage gate this ships confident garbage. Non-negotiable for MVP: human-in-the-loop.
- **Auto-inferring `route:`/`screen:`/`sheet:` navigation targets from Figma.** Figma has no reliable signal for app route names or which taps open a sheet vs push a screen. Emit `action:""` / a `TODO` placeholder and let the human fill actions — don't hallucinate an action grammar the app must honor.

---

## Recommended shape

**MVP = A + C + E.** Screenshot+metadata classify into the 14-type vocab → `validateDocument` → render-preview with a coverage report → human sign-off → write a wire `.json`. Encode the semantics-only wall (E) in the skill from day one.

**Then B** for the screens that matter (the `neo:` annotation convention) to turn inference into lookup where reliability counts.

**Then D** (`--publish` to Remote Config) once A/C are trusted — it's a thin, low-risk tail.

The risk is entirely in the classification + verification loop (A/C), not the plumbing (D). Spend the effort there; the invariant already did most of the hard work for you.

## Open questions for `ce-brainstorm` (if you take one forward)
1. Ingestion default: MCP (`get_metadata`+`get_screenshot`) vs REST token vs pasted screenshot — which is the primary path, given MCP availability varies by environment?
2. Does the skill target *whole-screen* documents or *per-block* fragments a human assembles?
3. Coverage-report bar: block on any dropped text node, or warn-and-continue?
4. Is the `neo:` annotation convention worth asking designers to adopt, or is inference + review good enough for the volume of guides you ship?
5. Publish: file-only, or wire the Admin-API push now?
