# neo_sdui wire contract — what you may emit, and what it will render

The **only** shapes `figwire` may emit, and — the half this file used to omit — what each one
actually renders. Source of truth in code: `packages/neo_sdui/lib/src/blocks/`,
`.../model/{block_node,validation,validate_vocabulary,view}.dart`, `.../theme/neo_sdui_theme.dart`,
`.../render/neo_sdui_view.dart`.

Every `file:line` below is an **anchor, not an address**: the quoted expression is the fact. If a
line has moved, grep the expression.

## Contents

- [The wire does not decide the look](#the-wire-does-not-decide-the-look) — read first
- [Document shape](#document-shape)
- [The 15 core block types](#the-14-core-block-types-allowlist)
- [Fields, per block](#fields-per-block)
- [The trigger index](#the-trigger-index) — every look that is **not** a plain wire field
- [Silently dead inputs](#silently-dead-inputs)
- [Cross-cutting field shapes](#cross-cutting-field-shapes)
- [Action grammar](#action-grammar)
- [The invariant — never on the wire](#the-invariant--never-on-the-wire)
- [A minimal valid document](#a-minimal-valid-document)

## The wire does not decide the look

A rendered pixel is a function of **three** inputs. This file documents all three:

| # | input | owned by | why it bites |
|---|---|---|---|
| 1 | **wire field** | you | `emphasis` · `tone` · `variant` · `layout` · `align` · `shape` |
| 2 | **theme-role nullity** | the app's `NeoSduiTheme` | it **forks the widget tree** — identical `steps` JSON renders as two structurally different widgets depending on whether the app sets `stepCardColor` |
| 3 | **render context** | the renderer, implicitly | a `header` nested under a `group` renders on the theme's `body` scale, not its `title` scale — no wire field says so |

Inputs 2 and 3 are not decoration on top of input 1, and you cannot see them in the design.

**The gate.** For each element of the design, name its trigger in the
[trigger index](#the-trigger-index) *before* emitting the block.

- trigger is a **wire field** → emit it.
- trigger includes a **theme role** or a **context** → emit, and state the assumption in the
  handoff: name the role and whether the target theme sets it. "Copy button needs
  `theme.stepCardColor != null`" is a sentence a human can check in seconds.
- **no trigger exists** → escalate. Do not emit a lookalike.

## Document shape

```json
{ "version": 1, "blocks": [ <block>, ... ], "views": { "<id>": <view> } }
```

- `version` — int (use `1`).
- `blocks` — the page's root blocks, in reading order.
- `views` — optional map of sub-screens targeted by `screen:`/`sheet:` actions.

**View:** `{ "present": "sheet" | "screen", "title": "<string>", "blocks": [ <block>, ... ] }`

- `present` defaults to `sheet` — anything but the exact string `"screen"` falls back (`view.dart:10-11`).
- `title` (optional) is the **app-bar title of the pushed sub-view** — "Claude MCP", "FAQs"
  (`view.dart:29`). The package parses it and hands the whole `NeoView` to the host's
  `NeoViewPresenter` (`neo_sdui_view.dart:20-21,265`); the **host** paints the app bar. A view
  without a `title` gets whatever bare chrome the host defaults to — this is the only wire field
  that reaches the app bar.

**Block envelope:** `{ "type": "<one of the 15>", ...content fields }`. Optional `fallback` (a full
block, rendered if the type is unknown/unsupported) and `requires` (`{feature: minVersion}`) — you
will rarely emit these.

**Reserved keys** a block may NOT use as content fields: `version`, `blocks`, `views`, `present`.

## The 15 core block types (allowlist)

`header · text · cta · callout · media · code · card · steps · faq · accordion · tabs · row · column · group · spacer`

Emitting any other `type` is a **hard error** — the renderer drops it and the block vanishes
(`kCoreBlockTypes`, `validate_vocabulary.dart:43`).

## Fields, per block

Every field the builders read. A field absent from this table is **not read** — it is dead JSON.
Forks live in the [trigger index](#the-trigger-index); this table is vocabulary only.

| type | required | optional | notes |
|---|---|---|---|
| `header` | `title` (string-or-runs) | `subtitle` (**string only**), `tone`, `icon`, `align:"center"` | `align:"center"` centers title+subtitle across the card (`header.dart:34`) — the "Still having issues?" footer. There is no right-align. |
| `text` | `body` (string-or-runs) | `emphasis`, `tone`, `variant:"footnote"` | `variant:"footnote"` = caption scale, muted (`text.dart:14`) — the figma "Note: …" disclaimer. **This is a dimmed line, not a card**; do not force-fit a `card`/`callout` for it. A run `{"text":…,"tone":"strong"}` renders white at the client's emphasis weight (w500); the wire names emphasis, never the weight. |
| `cta` | `label` (**string only**) | `action`, `emphasis`, `shape`, `align:"center"` | `align:"center"` hugs the label and centers the pill (`cta.dart:31`); default stretches to the column width. No icon; no runs label. |
| `callout` | `title` OR non-empty `bullets` | `tone`, `shape`, `icon` | `bullets` is **string-or-runs per entry** (`callout.dart:22-29`), not `string[]` — an inline accent phrase rides a bullet. Bullet styling is **positional and unwireable**: `bullets[0]` renders emphasized (full white), the rest at 70%; dots appear only when `bullets.length > 1` (`callout.dart:81-89`). |
| `media` | `url` | `ratio` (num>0) **or** `width`+`height` (ints), `shape` | add-on `neo_sdui_media` also reads `kind:"image"\|"video"`, `loop`, `mute`, `autoplay` (`media_addon.dart:20,39-41`); **core ignores all four**. |
| `code` | `content` (**verbatim**) | `label` | add-on `neo_sdui_syntax` also reads `language` (`syntax_code.dart:16`); **core ignores it**. |
| `card` | `title` (**string only** — runs render *empty*, `card.dart:75`) | `subtitle`, `action`, `actionLabel`, `thumb`, `variant:"tile"`, `ratio` (or `width`+`height`), `shape`, `emphasis`, `icon`, `tone` | `actionLabel` ("Open Guide →") replaces the default `›` caret. `icon`/`tone` are read **only** in the listed form (`card.dart:203`) — see [silently dead inputs](#silently-dead-inputs). |
| `steps` | non-empty `items` | `tone` (number-badge hue), `layout:"row"` | `layout:"row"` = the compact 1·2·3 strip (badge over caption); default is the vertical checklist. **Item:** `caption` (string-or-runs, **required**), `detail` (string), `code` (string), `image` (url string), `ratio` (num>0), `emphasis:"high"`, `blocks` (block[] — composed content under the caption; the one place a step holds child blocks instead of a baked `image`). `layout:"row"` reads **only** `caption` + `detail` (`steps.dart:66-83`). |
| `faq` | non-empty `items` | — | each item: `question` + `answer` — **plain strings only**; a non-string coerces to `''` (`faq.dart:15`). No runs, no gradient, no per-item action, no default-open. |
| `accordion` | `title` (string-or-runs), non-empty `children` (block[]) | — | a collapsible section holding any blocks; **starts closed**, tap the head to open (client-owned state, no default-open). `children` are ordinary blocks (a nested `steps` keeps its look). Emit a `fallback` (a `column` of the same children) so an app without the type shows the content open instead of dropping it. |
| `tabs` | non-empty `tabs` | `header` (block[]) | each tab: `label` (string), `blocks` (block[]). `header` is a shared block list rendered **above every tab** (`tabs.dart:20,148`). Tabs are `Expanded` — 5+ labels crush. |
| `row` | non-empty `children` (block[]) | — | every child is `Expanded` → **equal width, always**. |
| `column` | non-empty `children` (block[]) | `variant:"tight"` | `tight` → `spaceMd` gaps instead of `blockSpacing` (`layout.dart:34`) — the figma picker-card group. |
| `group` | non-empty `children` (block[]) | `shape`, `emphasis:"high"`, `variant:"list"`, `variant:"tight"` | stack on a themed surface. `variant:"list"` → the shared nav card (`layout.dart:65`); `variant:"tight"` → `spaceSm` child gaps (`layout.dart:98`); `emphasis:"high"` → featured. A `group` **reshapes its descendants** — see the trigger index. |
| `spacer` | — | `size` (int gap multiplier, clamped 0–100), `variant:"rule"` | `variant:"rule"` **ignores `size` entirely** and draws a bare 1px **dashed**, full-bleed line (`layout.dart:167-181`) — the surrounding block gap already spaces it. It is not a hairline centered in a gap. |

## The trigger index

Every look that is **not** a plain wire field, and its actual trigger. `∧` = all of these, or the
look does not appear. "—" = that input plays no part.

| the design shows | wire | ∧ theme role | ∧ context | where |
|---|---|---|---|---|
| **Copy button** ("Copy Command", on a hero panel) | `steps` item `emphasis:"high"` ∧ non-empty `code` | `stepCardColor != null` | — | `steps.dart:130,211,217,256` |
| **Copy chip** on a step (small boxed pill) | `steps` item `code` | `stepCardColor == null` — the theme **suppresses** it | — | `steps.dart:130,145-147` |
| **Copy chip** in a `code` block | `code` block | — **unconditional and inseparable** | — | `code.dart:85` |
| **Carded step** (surface + "Step n:" label + full-bleed image) | — **no wire field at all** | `stepCardColor != null` | — | `steps.dart:130` |
| **Boxed 1·2·3 cells** | `steps` + `layout:"row"` | `stepCardColor != null` | — | `steps.dart:34-35,86-98` |
| **Grid texture** behind a group | `group` + `emphasis:"high"` | `gridLine != null` (spacing = `gridSpacing`) | — | `layout.dart:122-132` |
| **Grid texture** in the hero command card (2nd site) | (as Copy button) | none — hardcoded `accent@12%`, **ignores `theme.gridLine`**, honors `gridSpacing` | — | `steps.dart:543-545` |
| **Grain / noise** overlay | (as Copy button) | `grainOverlay != null` | — | `steps.dart:525,552` — **the only call site in the package**; unreachable anywhere else |
| **Neumorphic emboss** — featured cta | `cta` + `emphasis:"high"` | `ctaGradient != null` | — | `cta.dart:32,42` — **the one neumorphic look the wire can ask for** |
| **Neumorphic emboss** — tab strip (groove + pressed pill) | any `tabs` | none — always | — | `tabs.dart:63,80` |
| **Neumorphic emboss** — hero card edge + its Copy button | (as Copy button) | none — always inside it | — | `steps.dart:593,612` |
| **Neumorphic picker card** (40px thumb + gradient + hairline) | `card` with `thumb` ∧ `variant != "tile"` — **inferred from field presence, no flag** | the 40px-thumb **row** needs none; the *gradient* needs `cardGradient`, the *hairline* needs `cardGradient` ∧ `stepCardBorderColor` | — | `card.dart:55-57,124,244` |
| **Featured card gradient** | `card` + `emphasis:"high"` | `cardGradient != null` | — | `card.dart:51` |
| **Card hairline border** | any card that got a gradient (`emphasis:"high"` **or** picker) | `stepCardBorderColor != null` | — | `card.dart:244` |
| **Flat nav row** (icon + label + caret, no surface of its own) | `group` `variant:"list"` **OR** *every* child is a `card` (auto-inferred) | — | ancestor `group` pushes `CardListed` | `layout.dart:63-65`, `card.dart:64` |
| **Title white→grey emboss** | `header` with **no** `tone` | `titleGradient != null` | **not** nested in a `group` | `header.dart:55-56` |
| **"Step n:" emboss** | (as carded step) | `titleGradient`, **else a baked white→#999 fallback** | — | `steps.dart:302-307` — ⚠ a missing `titleGradient` degrades **differently here than in `header`**: the header goes flat, the step label stays embossed on baked stops. Same role, two degrade paths. |
| **Compact heading** (sub-heading scale, not section scale) | `header` | — | **nested under a `group`** — but **not** a `variant:"list"` group | `header.dart:36,42-45`, `layout.dart:101` — top-level → `theme.title`; nested → `theme.body` at w500. ⚠ the list branch returns at `layout.dart:65-87`, *before* the `HeadingScale` wrap, so a `header` inside a list group stays at **section** scale. |
| **Pinned floating tab strip** (stays under the app bar, transparent gutters) | `tabs` | — | **top-level block only** | `neo_sdui_view.dart:101,114,182`, `tabs.dart:139` |
| **Boxed tab strip** (scrolls away with its content) | `tabs` | — | **nested** (in a group / tab / step) | `tabs.dart:19` |
| **Tappable underlined links** (URLs + bare domains auto-linked) | carded step whose `caption` is a **plain String** | `stepCardColor != null` | — | `steps.dart:227-232` (the `cap is String` fork), `:319-322` (the matcher: schemes + bare `.com\|.ai\|.xyz\|.io\|.org\|.net\|.dev`) — ⚠ **runs kill it**: a `caption` written as a run list silently loses every link |
| **Inline command echo** after a caption | carded step with `code`, caption doesn't already contain it | `stepCardColor != null` | — | `steps.dart:221` |
| **Background gradient** | — **no wire path** | `backgroundGradient != null` | — | `neo_sdui_view.dart:208-209` |
| **Featured group gradient** | `group` + `emphasis:"high"` | `groupGradient != null` | — | `layout.dart:149` |
| **Callout card gradient** | `callout` with `tone != "critical"` | `cardGradient != null` | — | `callout.dart:36` |
| **Accent text gradient** (heading, run, step number) | `tone:"<role>"` block- or run-level | that role's `NeoAccent.gradient != null` | — | `_gradient_text.dart:36,52` — null gradient → flat role color |
| **App-bar title** on a pushed sub-view | `views.<id>.title` | — | host paints it | `view.dart:29`, `neo_sdui_view.dart:265` |

## Silently dead inputs

Read nowhere, or read and discarded. They validate clean and render nothing — the worst failure
mode there is.

- **`card.icon` / `card.tone`** are read **only** inside a `variant:"list"` group (`card.dart:203`).
  On a standalone card, a tile, or a picker card they are dead. Nav icons need the list group.
- **`steps.tone` is dead in carded mode.** `numberTone` is passed to `_cardedItem` and never
  referenced in its body (`steps.dart:201`) — a carded step draws no number badge. It works in the
  bare checklist (`steps.dart:163`) and in `layout:"row"` (`steps.dart:75`).
- **`steps.items[].code` is ignored entirely** under `layout:"row"` — the cell reads only `caption`
  and `detail` (`steps.dart:66-83`).
- **`card.title` / `cta.label` / `faq` Q+A as runs** → empty or `''`. They are `stringOr`/`_str`
  reads. Only `header.title`, `text.body`, `callout.title`, `callout.bullets[]` and
  `steps.items[].caption` accept runs.
- **`tabs.header` is not walked by the validator** (`validate_vocabulary.dart:104-111` recurses
  `tabs[i].blocks` only). An off-roster type inside `tabs.header` passes validation and then
  vanishes at render. Check it by eye.
- **A typo'd enum degrades silently** — `emphasis:"High"`, `variant:"List"` are never validated;
  they just don't match, and the look quietly reverts to the default.

## Cross-cutting field shapes

**string-or-runs** (`header.title`, `text.body`, `callout.title`, `callout.bullets[]`,
`steps.items[].caption`): either a plain string, or a list mixing strings and accent runs:

```json
["Sign in with your ", { "text": "NeoSapien", "tone": "accent" }, " account"]
```

A run is `{ "text": "<string>", "tone": "<role>" }`. A run's `tone` overrides the block's; a run
with no `tone` inherits it (`_gradient_text.dart:36`).

**`tone` — any accent role the theme declares. This is the escape hatch; it ships today.**

- `"accent"`, `"critical"` and `"warning"` are **built in** (`kBuiltinAccentTones`,
  `neo_sdui_theme.dart:21`) and resolve with **zero theme work** — `warning` is a **required**
  constructor param (`neo_sdui_theme.dart:47`), so `tone:"warning"` yields the theme's yellow on any
  theme that compiles at all (`accentFor`, `neo_sdui_theme.dart:251-262`).
- Beyond those, `accents` is an **open map** `Map<String, NeoAccent>` keyed by the tone name
  (`neo_sdui_theme.dart:236`). `accentFor` checks the named entry **first**, so a theme can add a
  hue (`"brand"`) *or override a built-in* (`neo_sdui_theme.dart:251-262`). A `NeoAccent` carries a
  color **and an optional gradient** (`neo_sdui_theme.dart:29-33`).
- So one screen can carry two accent hues — a title gradient and a different step-count gradient —
  with **no new block, no new field, and no hex on the wire**. If the design shows a colored text
  that is not the accent green, the answer is a named `tone` + a theme `accents` entry.
- Works at **block level** (`header`, `text`, `steps`, `callout`, listed `card`) and at **run
  level** — any role name, not just `"accent"`.
- An unmapped tone → the text/glyph keeps its plain, non-accent look. Never a hex or gradient stop
  on the wire; only the role **name**.
- ⚠ `callout` is **asymmetric**: `tone` tints the icon through the full role map, but the *title*
  color is a 3-way switch — `accent`→`theme.accent`, `critical`→`theme.danger`, anything else
  →`onSurface` (`callout.dart:39-43`). And `tone:"accent"` tints the **icon + title only**, never
  the box; only `tone:"critical"` tints the box (`callout.dart:35`).

**Enums (names only — the theme turns them into pixels):**

- `tone`: any accent role — see above.
- `emphasis`: `"high"` | `"low"` | (default `normal`).
- `shape`: `"squircle"` | `"rounded"`. An unrecognized token degrades to the block's default.
- `variant`: `"tile"` (card) · `"rule"` (spacer) · `"footnote"` (text) · `"list"`, `"tight"`
  (group) · `"tight"` (column).
- `align`: `"center"` (header, cta).
- `layout` (steps): `"row"`.
- `present` (view): `"sheet"` | `"screen"`.

**`icon` (open role, `header` / `callout` / listed `card`):** a **named** icon role — `"sparkle"`,
`"download"`, `"export"`, `"info"`, `"check"`, `"warning"`, `"help"`, `"chat"` (`kDefaultIcons`,
`neo_sdui_theme.dart:7`; a client swaps its own set). The wire names the icon only; the theme owns the glyph,
and its size + tone color are the block's (`tone` tints it). An unmapped/omitted name **draws
nothing**. Never a glyph, codepoint, emoji or asset path on the wire.

**`image` (per-`steps`-item):** a full-width network image above the step's row — the how-to
screenshot. Any gradient/look is **baked into the asset**, never the wire; the wire carries only the
`url` + optional `ratio`. Missing/unpublished asset → it **collapses** and the caption still renders
(`steps.dart:454-458`). Note `media` diverges: a failed `media` leaves an opaque box at full ratio
(`media.dart:39`).

## Action grammar

`cta.action`, `card.action` only.

| value | meaning |
|---|---|
| `route:<name>` | app-allowlisted named route |
| `sheet:<id>` / `screen:<id>` | open `views[id]` as a modal sheet / pushed screen |
| `closeSheet` / `closeAll` | pop |
| `https://host/...` | external link (https only) |

You cannot infer routes from a design — emit `"action": "TODO:<hint>"` and let a human wire it.

## The invariant — NEVER on the wire

No `#hex`/`rgb`, no `px`/`dp`, no `fontSize`/`fontFamily`/`fontWeight`, no gradient stops, no
shadows, no spacing/padding numbers. Only the role enums above + content + URLs + action strings.
All pixels live in the client-owned `NeoSduiTheme`. When a design's look has no wire trigger, the
fix is a **theme role**, never a wire value — see `theme-extract.md`. See `accent-tones.md` for
reading the accent green off a design; the roster of roles you may *name* is the `tone` section
above, which is wider than the green.

## A minimal valid document

```json
{
  "version": 1,
  "blocks": [
    { "type": "media", "url": "https://cdn.neosapien.xyz/neo/mcp/hero.png", "ratio": 1.6 },
    { "type": "header", "title": "Your AI. Finally in the loop.", "subtitle": "Connect Neo 1 memories to any AI." },
    { "type": "steps", "items": [
      { "caption": "Pick your AI", "detail": "ChatGPT, Claude or any other" },
      { "caption": "Follow the quick guide" }
    ] },
    { "type": "code", "label": "Your MCP server", "content": "https://api.neosapien.xyz/mcp" },
    { "type": "callout", "tone": "accent", "title": "Not getting results?", "bullets": [["Add ", {"text": "“from NeoSapien”", "tone": "accent"}, " to your message."]] },
    { "type": "text", "variant": "footnote", "body": "Note: MCP support varies by client." },
    { "type": "group", "variant": "list", "children": [
      { "type": "card", "title": "Troubleshooting", "icon": "help", "action": "screen:trouble" },
      { "type": "card", "title": "FAQs", "icon": "info", "action": "screen:faq" }
    ] }
  ],
  "views": {
    "faq": { "present": "screen", "title": "FAQs", "blocks": [
      { "type": "faq", "items": [ { "question": "What is NeoSapien MCP?", "answer": "It connects your AI to your memories." } ] },
      { "type": "cta", "label": "Contact Support", "action": "https://neosapien.xyz/support", "emphasis": "high", "align": "center" }
    ] }
  }
}
```
