---
date: 2026-07-10
topic: neo-sdui-pixel-authority-and-wire-economy
focus: Where pixel authority sits between (A) semantic+tokens and (B) generic+raw, given a `neo_ui` design-system package is coming; plus wire non-repetition and the pure-Dart/add-ons boundary.
mode: repo-grounded
---

# Ideation: `neo_sdui` — pixel authority, wire economy, package boundaries

37 raw candidates from 6 frames. 7 survive. 5 cut, 3 deferred with named triggers.
Every survivor was re-checked by a fresh-context verifier that never saw the generation.

---

## Grounding Context

**The subject.** A Flutter package, not yet written, that turns a JSON document from Firebase
Remote Config into baked widgets for pure-content screens — guides, walkthroughs, FAQs.
Two consumers: the existing `how_to` guide (today: remote HTML through `HowToHtmlView`,
471 LOC, `flutter_widget_from_html`), and a new 5-client MCP setup guide. A `neo_ui`
design-system package is planned but does not exist.

**Codebase context (measured this run).**

| Fact | Evidence |
|---|---|
| 77 `static const Color`, 33 `static final TextStyle`, all flat statics | `app_colors.dart:3`, `app_styles.dart:6` |
| **No `Map<String,Color>` / `Map<String,TextStyle>` anywhere under `lib/`** | grep — absent |
| **No `extends ThemeExtension` anywhere under `lib/`**, no `extensions:` in `app_theme.dart` | grep — absent |
| The one wire-token precedent: remote `String` → enum allowlist with `default:` | `how_to_cta_action.dart:8` `fromKey()` |
| `_injectMissingThumbDimensions()` injects the **constant** `width='1600' height='900'` | `firebase_remote_config.dart:241-248` |
| …and `bleCardBannerSheet` calls the same helper | `firebase_remote_config.dart:220-229` |
| Structural repetition, actual: CTA byte-identical ×3 (~50 B each) | `remote_config_defaults.dart:2` |
| `cta:exit` is declared and referenced **zero** times — dead config | `remote_config_defaults.dart:2` |
| The port's transcription surface: 6 URLs, 3 sheet ids, 2 cta ids | `remote_config_defaults.dart` |
| Repo already paid for codegen conflicts | `pubspec.yaml` → `dependency_overrides: {analyzer, dart_style}` |
| Sibling-package precedent | `pubspec.yaml:44-49` → `neo_ble` git dep with subdir `path:` |

**External context.**

- **Airbnb Ghost** — the only confirmed production SDUI that dedupes by reference with no wire
  templating: *"We point to section data models rather than including them inline. This shrinks
  response sizes by reusing sections across layout configurations."*
- **Adaptive Cards HostConfig** — `fontSizes{medium:14}`, `spacing{medium:20}`,
  `foregroundColors.attention.default = "#FF8B0000"`, all client-side. The card says
  `"size":"Medium"`, `"color":"attention"`.
  **Correction found by verification:** `Image.width` / `Image.height` *do* accept a raw pixel
  string (`"50px"`) in the card payload. Style is tokenized; **dimensions are not.**
- **Adaptive Cards `fallback` / `requires` / `version`** — an element declares an alternate
  subtree and a minimum feature version; the host renders the fallback when it can't satisfy
  `requires`. Verified in the schema explorer.
- **Adaptive Cards Templating** — `${...}` runs in a *separate SDK*, `template.expand({$root})`,
  **before** the renderer. The renderer never sees an expression. The carve-out that makes
  authoring-time expansion legal under a no-wire-expressions rule.
- **DivKit `templates`** — `$`-prefixed field renaming plus inheritance, no expression language.
- **rfw** — the remote payload can declare `widget foo = …` with `...args` spread and `...for`
  loops. Genuine remote structural reuse. Explicitly rejected by the senior.
- **Envelope shape** — Editor.js is the only one of the three carrying a nested `data` bag.
  Adaptive Cards and DivKit both flatten.
- **Nobody ships** base-document + JSON-Patch overlay, or `$ref`/`$defs` node dedupe, as an SDUI
  wire mechanism. Both exist as RFCs; neither has an SDUI witness.

**Settled constraints (resolved earlier in the discussion — not open for ideation).**

- **Remote Config is the source; no backend.** The "RC vs backend?" question was answered: no
  state in either flow needs a backend — all state is widget-local (`TabController`, the
  `Set<int>` accordion, `bool _copied`, the `Image.network` shimmer, `video_player`). The MCP
  command is a bare constant (OAuth happens in-browser), byte-identical per user, so the guide is
  not a function of the user. **One key per document; compiled-in defaults required.**
- **JSON on the wire, never YAML.** Dart's `loadYaml` implements anchors/aliases with no expansion
  limit and no cycle detection — the billion-laughs primitive (a few hundred bytes expand to
  gigabytes on dereference). RC *caches* the fetched value, so one bad console paste OOMs on fetch
  and survives relaunch. `loadYaml` also returns `Map<dynamic, YamlNode>`, not
  `Map<String, dynamic>` — every generated `fromJson` breaks. The format is telling us what it
  wants to be: JSON.
- **External URLs: `https` only.** Reject `javascript:`, `file:`, `intent:` at the action boundary
  (idea #1). Remote Config is console-controlled = semi-trusted, not trusted.

---

## Topic Axes

1. **Pixel authority** — who owns colors, spacing, type; where the HostConfig-equivalent lives.
2. **Wire economy** — how the JSON stops repeating itself, structurally and value-wise.
3. **Package boundaries** — `neo_sdui` / `neo_ui` / add-ons / app; the pure-Dart line.
4. **Extension & escape** — new block types; version skew; what happens when Figma outruns the vocabulary.
5. **Safety & failure** — malformed payloads, blast radius, the action allowlist.

---

## Ranked Ideas

### 1. Fix the unguarded `launchUrl` as part of the port

**Description.** `how_to_link_dispatcher.dart:90-94` passes a Remote-Config-authored string
straight into `launchUrl(Uri.parse(url))`. Add an `https`-only guard at the dispatcher, and
carry it into `neo_sdui`'s action boundary rather than re-deriving it later.

**Axis:** Safety & failure

**Basis** — `direct:`, verified end to end by a fresh-context reader:

```dart
// how_to_link_dispatcher.dart:90-94
case HowToCtaAction.openUrl:
  final url = cta.url;                 // how_to_cta.model.dart:34 — plain String?, no validation
  ...
  await launchUrl(Uri.parse(url));
  return true;
```

Reachable via `how_to_html_view.dart:196` `onTapUrl` → `HowToLinkDispatcher.parse` → `cta:` prefix
→ `ctaById` → `RunCtaIntent.execute()`. No scheme check in the model, the generated `fromJson`,
the dispatcher, or any wrapper. `ExternalUrlIntent` is a red herring — it `return false`s at
line 98 and never launches.

**Rationale.** This is the exact primitive the project's own security rule was written against:
*"A remote string that can push an arbitrary route is a deep-link injection primitive, and Remote
Config is console-controlled, which makes it semi-trusted, not trusted."* The rule exists; the
code predates it. `neo_sdui` inherits this dispatcher, so the guard lands in the port either way.

**Downsides.** None. Calibrated honestly, exploitation requires Firebase console access, and
`javascript:` / `file:` largely no-op on both platforms. What actually lands is deep-link
injection into Neo's own scheme or another installed app's (`neo://`, `tel:`, `market://`), plus
cleartext `http://`. Bounded, low likelihood, three-line fix.

**Confidence:** 100% · **Complexity:** Low

---

### 2. The middle is a layering, not a blend — with dimensions carved out

**Description.** Stop treating A↔B as a slider. Two artifacts with two owners:

- **The wire** carries semantic `type` + token *names*: `{"type":"callout","severity":"warning"}`.
- **A client-owned token table** maps names to pixels. Compile-time `const`, no hex on the wire.

The one carve-out, learned from Adaptive Cards rather than invented: **intrinsic media dimensions
are content, not style.** `image.width` / `image.height` are raw ints, because an asset's aspect
ratio belongs to the asset, not the theme. Everything else — colour, spacing, type, radius —
resolves through the table.

**Axis:** Pixel authority

**Basis** — `external:`, with a correction the verifier forced:
HostConfig is real (`fontSizes{medium:14}`, `foregroundColors.attention.default="#FF8B0000"`).
But the absolute claim "no pixel value ever appears in the card payload" is **false of the cited
precedent**: `Image.width` takes *"The desired on-screen width of the image, ending in 'px'.
E.g., 50px"* (adaptivecards.io/explorer/Image.html). Adaptive Cards tokenizes style and leaves
dimensions raw. Copy that, not the myth of it.

**Rationale.** DoorDash is the cautionary tale — they bolted a raw `Struct` fallback onto a
semantic model *"while these shouldn't be needed in most cases"* and it leaked. A resolver with
no code path that decodes a hex string cannot erode under deadline pressure. But a rule with no
carve-out for dimensions would force `_injectMissingThumbDimensions`'s successor into existence
all over again.

**Downsides.** A colour or spacing change becomes an app release. That is the trade the whole
design buys: a corpus-wide re-skin costs one package bump and touches zero documents.

**Confidence:** 90% · **Complexity:** Medium

---

### 3. Schema-declared defaults: absent on the wire means take the compiled-in default

**Description.** Every block field declares a default in the client's block schema. The wire omits
anything sitting at its default. The renderer fills it in. Value repetition vanishes under the
most boring rule available — *absent = default* — and `_injectMissingThumbDimensions()` gets
deleted rather than ported.

**Axis:** Wire economy

**Basis** — `direct:`, verified verbatim at `firebase_remote_config.dart:241-248`: the helper
injects a **hardcoded constant**, `width='1600' height='900'`, never a computed value — the
adjacent comment reads *"gets 1600x900 (matches placeholder asset, 16:9)"*. A schema default
replaces it exactly. `external:` protobuf / ASN.1 `DEFAULT`: a field at its default is never put
on the wire; the receiver reconstructs from the schema.

**Rationale.** This is the whole answer to *"I do not want to repeat the same values again and
again"* — the configuration half of it — and it retires a live regex hack as a side effect. Rare
trade: add a feature, delete a hack. The second consumer, `bleCardBannerSheet`
(`firebase_remote_config.dart:220-229`), calls the same helper and is fixed by the same move.

**Downsides.** A default that changes needs an app release. Mitigated by the fact that a default
is a *fallback*, never a ceiling — the wire can always override, so nothing becomes less editable
than it is today.

**Confidence:** 95% · **Complexity:** Low

---

### 4. Author-declared `fallback`, so a new document degrades on an old app

**Description.** Adopt three fields from the Adaptive Cards schema: a top-level `version`, a
per-block `requires` map, and a per-block `fallback` subtree built from already-shipped
primitives. A document authored today, landing on a six-month-old install, renders the author's
fallback instead of a hole.

**Axis:** Extension & escape

**Basis** — `external:`, verified in the schema explorer: `fallback` is *"Describes what to do
when an unknown element is encountered or the requires of this or any children can't be met"*;
`requires` is *"key/value pairs indicating features that the item requires with corresponding
minimum version"*; `version` — *"Schema version that this card requires. If a client is lower than
this version, the fallbackText will be rendered."*

**Rationale.** Remote Config has no negotiation channel, so the document must declare its own
floor. The verifier's attack — *"unknown type → skip the block already handles this"* — has a
real answer: for a **content** block, skip and fallback are a wash. For an **interactive** block
that gates progress (a "Continue" CTA), skipping strands the user with no way forward, while an
author-supplied plain-text link, shipped in the same payload, keeps old clients functional.
That is the case, and it is the only case — which is why `fallback` is worth exactly one field,
not a subsystem.

**Downsides.** Authors must think about the oldest supported app version. Nobody enjoys that, and
they will forget. CI can catch it: any block newer than the oldest supported release must carry
a `fallback` or fail validation.

**Confidence:** 80% · **Complexity:** Medium

---

### 5. `neo_sdui` declares the `ThemeExtension`; the **app** fills it from `AppColors`. Ship before `neo_ui`.

**Description.** `neo_sdui` declares `class NeoGuideTheme extends ThemeExtension<NeoGuideTheme>`
and nothing else about colour. The app registers it in `app_theme.dart` — `extensions: [NeoGuideTheme(bodyText: AppStyles.h7w400, calloutWarningBg: AppColors.bannerCriticalSurface, …)]`.
Blocks read it ambiently via `Theme.of(context).extension<NeoGuideTheme>()`. When `neo_ui` lands
it takes over supplying the extension. Nothing is sequenced behind a package that doesn't exist.

**Axis:** Package boundaries

**Basis** — `direct:` + a `reasoned:` argument the verifier repaired rather than refuted.
Grep confirms **no `extends ThemeExtension` and no `extensions:` anywhere under `lib/`** — this
map is net-new regardless of who owns it. The rejected variant of this idea had `neo_sdui` ship a
bespoke `abstract class NeoTokens` with a default implementation seeded from today's constants;
the verifier killed it precisely: that default impl would hardcode `Color(0xFF00F1A0)`, which is
the *literal* value of `AppColors.primary500` at `app_colors.dart:9` — a byte-for-byte copy in a
second file, reproducing the exact drift a design-system boundary exists to prevent. It also
noted a `String`-keyed `color(String)` lookup moves typos from compile time to runtime.
`ThemeExtension` is Flutter's own mechanism, is compile-time typed, requires no new dependency,
and requires `neo_ui` not to exist.

**Rationale.** This removes the only sequencing dependency in the plan. `AppColors` stays the
single source of truth. `neo_sdui` becomes shippable and testable this sprint, and the `how_to`
port — the engine's real regression test — is not gated on a design system nobody has started.

**Downsides.** The app must remember to register the extension; forgetting it means a null
extension at render time. Guard with a `NeoGuideTheme.fallback` const and one widget test.

**Confidence:** 90% · **Complexity:** Low

---

### 6. Homogeneous runs are data, not structure — but only where the run is genuinely homogeneous

**Description.** Where a guide contains N near-identical siblings, emit **one** block whose
payload is an array — `{"type":"steps","items":[{"caption":…,"image":…}, …]}` — and let the Dart
step-builder iterate. The loop is Dart, not wire syntax, so no expression language appears. Where
the run is *not* homogeneous, it stays a heterogeneous ordered list of blocks.

**Axis:** Wire economy

**Basis** — `reasoned:`, and materially narrowed by verification. The original claim was that this
solves the MCP guide's 5 × 11 step repetition outright. Two attacks land:

1. **Interleaving.** An array of `{caption, image}` cannot express *"step 3, then a warning
   callout, then step 4"* without smuggling callout/code into every step object — at which point
   it is a heterogeneous list wearing an array costume.
2. **Isolation.** Collapsing eleven blocks into one node means one malformed entry can take out
   all eleven, unless the builder adds its own per-item `try/catch` — reintroducing internally
   the complexity the array was supposed to remove.

Both are real. The idea survives *scoped*: `steps` is a specialization, available when the run is
homogeneous, with a per-item `try/catch` inside the builder. It is not the general answer to
structural repetition, and no general answer is needed yet (see the Rejection Summary).

**Downsides.** Two ways to express a sequence. Authors must know which to reach for. Acceptable
because the heterogeneous list is always legal and always correct; `steps` is a shorthand.

**Confidence:** 65% · **Complexity:** Low

---

### 7. Flatten the envelope — but reserve the keywords first

**Description.** `{"type":"callout","severity":"warning","text":"…"}`, not
`{"type":"callout","data":{"severity":"warning","text":"…"}}`. Reserve `type`, `fallback`,
`requires`, and `ref` as envelope keywords no block payload may use.

**Axis:** Wire economy

**Basis** — `direct:` from the prior-art sweep: Editor.js is the only one of the three systems
carrying a nested `data` bag (`{"id":…,"type":"header","data":{…}}`); Adaptive Cards flattens
(`{"type":"TextBlock","text":"…","spacing":"None"}`); DivKit flattens. The currently-planned
`{type, data}` envelope copies Editor.js's heaviest form for no stated reason.

**Rationale.** A free win taken before any code exists. One less nesting level on every node,
and the shape reads like the systems worth copying.

**Downsides.** Real, and surfaced by verification: a flat node has a namespace collision problem
the nested one does not. A `mediaCard` block that wants an internal discriminator (image vs
video) cannot call it `type`. Reserving four keywords costs nothing now and is impossible later.
The verifier also notes the block roster (`mediaCard`, `faq`, `tabs`) exists nowhere in this repo
yet — the collision is anticipated, not observed. Lowest-stakes item in the set; if it feels like
a coin flip, it is one.

**Confidence:** 60% · **Complexity:** Low

---

## Rejection Summary

| # | Idea | Reason rejected |
|---|---|---|
| 1 | `defs` map + `{"ref":"cta_back"}` pointer (Airbnb Ghost mechanism) | **Deferred, not wrong.** Airbnb's quote is real, but the measured saving here is ~50 bytes × 3 ≈ **100 bytes**, against an envelope concept, a resolution pass, cycle detection, and dangling-ref handling. YAGNI at 3 sheets. **Trigger to revisit:** a shared troubleshooting/FAQ tail actually repeats across ≥3 MCP guides, or the corpus passes ~20 documents. |
| 2 | DivKit-style `templates` block with `$`-prefixed field renaming | Strictly more machinery than idea 6 + deferred `ref`, and re-introduces a mini-language through the back door — the thing the senior rejected rfw for. |
| 3 | Golden-file the port: `matchesGoldenFile` diffing `HowToHtmlView` vs `neo_sdui` | **Refuted as stated.** `HowToVideoBlock` uses `video_player`'s `VideoPlayerController.networkUrl` — a native plugin with no decoder in the widget-test binding — and `Image.network` needs stubbing throughout. Even fully stubbed, diffing an HTML-CSS tree against a hand-built widget tree for byte-identical pixels loses to font hinting and line-breaking across CI machines. **Reshaped:** golden-test the *new* renderer against itself as a forward regression gate; compare against the old one by eye, once. |
| 4 | Machine-transcribe the `how_to` port with a throwaway HTML→JSON script | Cost case collapses on measurement: **6 URLs, 3 sheet ids, 2 cta ids** — about a dozen string pairs, one time. Careful copy-paste wins. (The scan did find `cta:exit` is declared and referenced **zero** times — delete it during the port.) |
| 5 | One shared token registry retiring `_iconFor`, `_paletteFor`, `FeaturePromoCardStyle` | **Refuted.** Three genuinely different shapes: `String→IconData`, `enum→_BannerPalette` (one colour), `enum→4 independent colour getters`. Unifying needs an abstraction more generic than any of the three wants. Also scope overrun — a refactor of shipped dashboard widgets, not a design decision for an unbuilt package. |
| 6 | "`neo_sdui` does not parse JSON" — take a decoded `Map`, app owns transport | Distinction without a difference. `jsonDecode` is `dart:convert`, zero deps either way; the package must still validate the decoded map, which is where the complexity actually lives. Real but minor test-ergonomics win; not a structural boundary. |
| 7 | `neo_sdui` ships a bespoke `abstract class NeoTokens` + default impl | Superseded by idea 5. The default impl would copy `AppColors.primary500`'s literal `Color(0xFF00F1A0)` into a second file — the drift a design-system boundary exists to prevent. `ThemeExtension` does it better and needs nothing new. |
| 8 | Auto-hoist duplicated subtrees at authoring time via content hashing (git/LZ77 analogy) | Deferred behind idea 1's trigger. At 8 documents this is a build tool nobody needs; the mechanism is sound and remains the right answer if the corpus grows. |
| 9 | Microkernel core: `neo_sdui` ships **zero** blocks, only a registry | The registry survives (it is how `neo_sdui_video` plugs in without forking). The zero-blocks purity does not — the stated requirement is *"take json and give a baked widget, with all the theming in place."* Batteries included, registry exposed. |
| 10 | Derive the token table from `AppColors` statics via a dev-time `analyzer` script | Solves a drift problem that idea 5 removes by construction — the app reads `AppColors` directly, so there is no second table to drift from. |
| 11 | Generate the block schema from the parser's registry rather than hand-maintaining it | Too expensive relative to value at 8 documents and ~14 block types. Revisit if the block count passes ~40. |
| 12 | "No `freezed` in core", "bundle Work Sans as package assets" | **Weak — restates a given.** Both are already binding constraints, not ideas. They belong in the package's contributing notes, which is where they will go. (`CLAUDE.md` prescribing Freezed as house style does make the first PR likely to import it — worth two lines in the README.) |

**Axis coverage.** All five axes carry at least one survivor. Package boundaries is thinnest
(one survivor, idea 5) — because the pure-Dart line and the add-on split were settled before this
run, and the ideas that revisited them either restated constraints (#12) or lost to a simpler
mechanism (#7, #9, #10).

---

## Page transitions — RESOLVED (2026-07-10)

**Decision: the JSON names a destination; the app owns the router and the animation.**

The wire carries `{"action":"route:askNeo"}` and nothing about how the push looks. The app
(`neo`, never the package) resolves the name through a hardcoded allowlist and pushes with the
transition `app_router.dart` already defines:

```dart
const _allow = {'askNeo': AskNeoRoute.new, 'profile': ProfileRoute.new};
final make = _allow[uri.path];        // allowlist — never uri.path raw
if (make != null) context.router.push(make());
// transition = the existing CustomRoute(transitionsBuilder: …) for that route
```

Rejected: (2) JSON also picks the transition via a token — adds an animation vocabulary the app
must own and version against every release, and `rfw`'s README is blunt that remote-driven page
transitions are a known failure mode. (3) the package owns a `Navigator` — drags `auto_route`
and routing state into a package whose whole premise is `flutter` and nothing else.

`route:` resolves through the hardcoded allowlist, never `uri.path` directly. This is the same
prefix-dispatch shape `how_to_link_dispatcher.dart` already uses for `sheet:`. **No open design
questions remain — ready for CE.**

---

## The concrete shape — what Remote Config sends, what the package does

This consolidates the settled decisions above into one picture. It is the *starting contract*
CE will formalize (block roster, exact field names, validation) — not a frozen spec.

### The document (stored under one Remote Config key, as JSON)

Flat envelope: every node is `{"type": …, …fields}` — never `{"type":…,"data":{…}}`. A top-level
`version`, then an ordered `blocks` list. Reserved keywords no block payload may reuse: `type`,
`version`, `blocks`, `requires`, `fallback`, `ref`.

```json
{
  "version": 1,
  "blocks": [
    { "type": "step", "index": 1, "caption": "Open the Neo app", "image": "https://cdn.neo/s1.png" },
    { "type": "callout", "severity": "warning", "text": "Requires a laptop for setup" },
    { "type": "cta", "label": "Open Ask Neo", "action": "route:askNeo" },
    { "type": "cta", "label": "Read the docs", "action": "https://neosapien.xyz/docs" }
  ]
}
```

A newer block carries its own floor + escape hatch, so an old app degrades instead of breaking:

```json
{
  "type": "videoCard",
  "requires": { "video": "1.2" },
  "url": "https://cdn.neo/clip.mp4",
  "fallback": { "type": "cta", "label": "Watch on web", "action": "https://neosapien.xyz/clip" }
}
```

### Tokens vs raw (the "layered middle")

Style values are **token names**, resolved client-side: `"severity":"warning"` → a colour from the
`ThemeExtension`. The **only** raw values are intrinsic media dimensions (`image.width` /
`image.height` as ints) — an asset's aspect ratio is content, not theme. No hex, no `fontSize`, no
`padding` on the wire. Anything omitted takes its compiled-in schema default (kills repetition).

### What the package receives

The app does `jsonDecode` on the Remote Config string (`dart:convert`, zero deps) and hands
`neo_sdui` a `Map<String, dynamic>`. The package then:

1. **Validates** the map (shape, reserved keywords, `version`).
2. **Maps each block** `type` → a widget via an internal **registry** (this is also how the
   `neo_sdui_video` add-on plugs in without forking the core).
3. On an **unknown or unsatisfiable** block: render its `fallback` subtree; if none, skip it.
4. Reads colours/type **ambiently** via `Theme.of(context).extension<NeoGuideTheme>()` — the app
   fills that extension from `AppColors`.

### State, shimmers, animations — all widget-local, never on the wire

The wire is a **static description**. It carries no state, no durations, no curves. Everything
interactive or animated is owned by the widget the renderer builds:

| Concern | Where it lives | Example |
|---|---|---|
| Tab selection | `TabController` inside the `tabs` widget | 5-client MCP guide |
| Accordion open/closed | `Set<int>` inside the `faq`/section widget | expandable steps |
| "Copied!" feedback | `bool _copied` inside the copy-button widget | MCP command block |
| Image loading shimmer | `Image.network` `loadingBuilder` inside the media widget | every remote image |
| Video playback | `video_player` inside the `neo_sdui_video` add-on | video guide |

Animations (accordion expand, shimmer sweep) use Flutter's own
`SingleTickerProviderStateMixin` / `AnimatedContainer` — inside the widget, sourced from the
theme, never from the JSON.

### Routing & transitions

The wire names a **destination only**: `"action": "route:askNeo"`. The **app** (`neo`, never the
package) resolves that name through a **hardcoded allowlist** — never `uri.path` raw — and pushes
with the transition `app_router.dart` already defines. External links go through the same action
boundary: `https` only. **`neo_sdui` never imports `auto_route` and never touches a `Navigator`** —
that would break the `flutter`-and-nothing-else premise.

### Built with Compound Engineering, throughout

Every step after scaffolding runs through the Compound Engineering plugin, authored from inside
`neo_sdui/`: **`ce-brainstorm`** to turn this contract into a requirements-only spec →
**`ce-plan`** for the build sequence (port `how_to` first as the regression gate, then the MCP
guide) → **`ce-work`** to implement. The block roster, field names, and validation rules are all
settled through CE, not hand-authored. This ideation doc is the seed CE reads from.

---

## Bootstrap — scaffold the package, then everything runs through Compound Engineering

`neo_sdui` is its **own git repo**, sibling to `neo` — mirrors `neo_ble` (`pubspec.yaml:44-48`:
separate repo, pinned by tag, git dep). This physically enforces the pure-Dart line: a sibling
repo cannot import `neo`'s app code. **Flat layout** now (repo root = the core package); federate
into subdirs only when the first native add-on (`neo_sdui_video`) actually lands — same YAGNI
trigger as the deferred `defs`/`ref`.

**Add-ons live inside this same repo as sibling packages — never a separate repo per add-on.**
This mirrors `neo_ble` (one repo: `neo_ble` facade + `neo_ble_android`/`neo_ble_ios`/
`neo_ble_platform_interface` siblings, resolving by relative `path:` within the same checkout, and
**one tag pins the whole set** — `ref: v0.0.12`). Separate repos would fracture versioning: each
add-on would tag independently, a core bump would silently break out-of-sync add-ons, and `neo`
would carry N git deps instead of one. When the first add-on lands, `git mv` the core into a
`neo_sdui/` subdir and add the add-on package beside it. Native add-ons use `--template=plugin`
(they bring `video_player` etc.); the core stays `--template=package` (no native).

**What triggers a sibling add-on — one test:** does the feature need anything beyond `flutter` +
`meta` (a third-party pub package *or* native code)? Yes → add-on sibling. A Flutter built-in
covers it → stays in the core, nothing to install. **Images do not trigger a sibling:** Flutter's
built-in `Image.network` (with `loadingBuilder` for the shimmer, `errorBuilder` for the fallback,
in-memory cached) is exactly what the current guide already uses (`how_to_html_view.dart:260`);
the MCP guide reuses it as-is. `cached_network_image` would only be needed for *disk-persistent*
caching, and it pulls `flutter_cache_manager` → `path_provider`/`sqflite` (native), so it can never
sit in the core — it would be an add-on, and it is YAGNI for guide screenshots. **Same-repo
siblings are officially supported:** path deps (`{path: ../sibling}` — what `neo_ble` uses, works
on any SDK) or pub workspaces (`resolution: workspace`, Dart 3.6+, one shared lockfile). Use path
deps to match `neo_ble` unless the SDK is bumped to 3.6.

1. `cd /Users/vaibhavp/code/neosapien && fvm flutter create --template=package neo_sdui`
2. Pin Flutter to neo's version: `cp neo/.fvmrc neo_sdui/ && (cd neo_sdui && fvm install)`
3. Trim `neo_sdui/pubspec.yaml` to the two-dep core — `flutter` + `meta`; dev `flutter_test` +
   `flutter_lints`. **No `freezed` / `json_serializable` in core** (constraint #12 made physical).
4. `git init` + first commit in `neo_sdui/`
5. Save this file into the package: `neo_sdui/docs/ideation/neo-sdui-pixel-authority-and-wire-economy.md`
   — CE's ideation home, where `ce-brainstorm`/`ce-plan` will read it.

Wiring `neo → neo_sdui` is **deferred** — nothing to import until the renderer exists; then a git
dep mirroring `neo_ble` (`git url` + `ref:` tag) with a local `dependency_overrides` path during
active dev.

**From here, every step is the Compound Engineering plugin, run from inside `neo_sdui/`:**
ideate → brainstorm → plan → work. Nothing further is authored by hand.
