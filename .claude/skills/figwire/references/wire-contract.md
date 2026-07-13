# neo_sdui wire contract — the output vocabulary

The **only** shapes `figwire` may emit. The wire carries **semantics**, never look.
Source of truth in code: `packages/neo_sdui/lib/src/blocks/`, `.../model/block_node.dart`,
`.../model/validation.dart`, `.../model/validate_vocabulary.dart`.

## Document shape

```json
{ "version": 1, "blocks": [ <block>, ... ], "views": { "<id>": <view> } }
```

- `version` — int (use `1`).
- `blocks` — the page's root blocks, in reading order.
- `views` — optional map of sub-screens targeted by `screen:`/`sheet:` actions.

**View:** `{ "present": "sheet" | "screen", "blocks": [ <block>, ... ] }` (`present` defaults to `sheet`).

**Block envelope:** `{ "type": "<one of the 14>", ...content fields }`. Optional `fallback` (a full block, rendered if the type is unknown/unsupported) and `requires` (`{feature: minVersion}`) — you will rarely emit these.

**Reserved keys** a block may NOT use as content fields: `version`, `blocks`, `views`, `present`.

## The 14 core block types (allowlist)

`header · text · cta · callout · media · code · card · steps · faq · tabs · row · column · group · spacer`

Emitting any other `type` is a **hard error** — the renderer drops it and the block vanishes.

| type | required | optional | notes |
|---|---|---|---|
| `header` | `title` (string-or-runs) | `subtitle` (string), `tone` | title line |
| `text` | `body` (string-or-runs) | `emphasis`, `tone` | body copy |
| `cta` | `label` (string) | `action`, `emphasis`, `shape` | button |
| `callout` | `title` OR non-empty `bullets` (string[]) | `tone`, `shape` | highlighted box |
| `media` | `url` (string) | `ratio` (num>0), `kind` (`image`/`video`, add-on), `width`/`height` | image/video |
| `code` | `content` (string, **verbatim**) | `label` (string), `language` (add-on) | copyable command/URL |
| `card` | `title` (string) | `subtitle`, `action`, `thumb`, `variant:"tile"`, `ratio`, `shape` | tappable card |
| `steps` | non-empty `items` | — | each item: `caption` (string-or-runs, **required**), `detail` (string), `code` (string) |
| `faq` | non-empty `items` | — | each item: `question` + `answer` (strings, **required**) |
| `tabs` | non-empty `tabs` | — | each tab: `label` (string), `blocks` (block[]) |
| `row` | non-empty `children` (block[]) | — | side-by-side |
| `column` | non-empty `children` (block[]) | — | vertical stack |
| `group` | non-empty `children` (block[]) | `shape` | stack on a themed surface |
| `spacer` | — | `size` (int, gap multiplier) | vertical gap |

## Cross-cutting field shapes

**string-or-runs** (for `header.title`, `text.body`, `steps.items[].caption`): either a plain
string, or a list mixing strings and accent runs:

```json
["Sign in with your ", { "text": "NeoSapien", "tone": "accent" }, " account"]
```

A run is `{ "text": "<string>", "tone": "accent" }`. Only `tone:"accent"` is meaningful at run level.

**Enums (names only — the theme turns them into pixels):**
- `tone`: `"accent"` | `"critical"` (block level); `"accent"` only (run level).
- `emphasis`: `"high"` | `"low"` | (default `normal`).
- `shape`: `"squircle"` | `"rounded"`.
- `variant` (card): `"tile"`.
- `present` (view): `"sheet"` | `"screen"`.

**Action grammar** (`cta.action`, `card.action` only):

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
All pixels live in the client-owned `NeoSduiTheme`. See `accent-tones.md` for the one place a
visual (the accent color) maps to a wire name.

## A minimal valid document

```json
{
  "version": 1,
  "blocks": [
    { "type": "media", "url": "https://cdn.neosapien.xyz/mcp/hero.png", "ratio": 1.6 },
    { "type": "header", "title": "Your AI. Finally in the loop.", "subtitle": "Connect Neo 1 memories to any AI." },
    { "type": "steps", "items": [
      { "caption": "Pick your AI", "detail": "ChatGPT, Claude or any other" },
      { "caption": "Follow the quick guide" }
    ] },
    { "type": "code", "label": "Your MCP server", "content": "https://api.neosapien.xyz/mcp" },
    { "type": "callout", "tone": "accent", "title": "Not getting results?", "bullets": ["Add “from NeoSapien” to your message."] },
    { "type": "card", "title": "FAQs", "action": "screen:faq" }
  ],
  "views": {
    "faq": { "present": "screen", "blocks": [
      { "type": "header", "title": "FAQs" },
      { "type": "faq", "items": [ { "question": "What is NeoSapien MCP?", "answer": "It connects your AI to your memories." } ] },
      { "type": "cta", "label": "Contact Support", "action": "https://neosapien.xyz/support", "emphasis": "high" }
    ] }
  }
}
```
