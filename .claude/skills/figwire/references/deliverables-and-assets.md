# Deliverables & assets — where a guide's output lands, and its images

figwire's output is a **deliverable folder** the user reviews and uploads to the CDN as-is: the wire doc
**plus** its image assets. Exporting them does **not** break the Iron Rule — the wire carries only the
image **URL string**, never bytes or pixels.

[Folder](#the-deliverable-folder) · [One JSON per family](#one-json-per-guide-family--not-per-screen) ·
[Multi-frame](#multi-frame-guides--collapse-frames-dont-multiply-screens) · [Export](#assets--export-name-group) ·
[URLs are probed](#urls-are-probed-never-derived-gate) · [Open the PNG](#open-the-png-before-you-wrap-it) ·
[Add-on manifest](#required-add-on-manifest--the-handoff-owes-this) · [Verify](#verify)

## The deliverable folder

Gitignored (add the line to the repo `.gitignore` if absent). One folder per **guide-family**; the json
name **is** the family name (`mcp.json`, not `mcp_guide.json`):

```
deliverables/           ← gitignored (CDN staging, never committed)
  mcp/
    mcp.json            ← the ONE wire doc for the whole family
    assets/             ← S3 key public/neo/mcp/assets/ → cdn.neosapien.xyz/neo/mcp/assets/
      hero.png
      icons/    chatgpt.png  claude.png  connectors.png
      chatgpt/  web-1.png  desktop-1.png  …
      other/    step-0.png … step-3.png
```

Only the **filename and sub-path under `assets/`** are identical local ↔ CDN ↔ wire — **never rename**
between them. The folder is **not** a model of the URL root; see the probe rule.

| asset kind | path | why |
|---|---|---|
| hub hero | `assets/hero.png` (flat) | one, top-level |
| client / card icons | `assets/icons/<name>.png` | few, shared on the hub |
| per-step screenshots | `assets/<client>/<tab>-<n>.png` | many, client-scoped |

## One JSON per guide-family — not per screen

**Root `blocks`** = the entry/hub screen; **`views`** = every sub-screen (per-client guides, FAQ,
troubleshooting), each `{present:"screen", blocks:[…]}`. A **shared tail** stamped on every screen (FAQ /
troubleshooting / use-cases) is ONE view referenced by `screen:<id>` — never re-embedded per screen.

Remote Config's only limit is 1,000,000 chars across the whole project (no per-value cap); a family is
~40–60K. Splitting multiplies chars and adds cross-doc `route:` wiring. **Split only if** one family
nears hundreds of KB, per-screen lazy-fetch becomes real, or a tail repeats across ≥3 *separate*
families (`docs/ideation/neo-sdui-pixel-authority-and-wire-economy.md`). A genuinely separate family
(`mcp` vs `how_to`) is always its own doc / RC key.

## Multi-frame guides — collapse frames, don't multiply screens

One screen is often several Figma **frames**. Map, don't transcribe 1:1:

- **Tabs are separate frames.** Web / Desktop / Code = 2–3 frames → **one `tabs` block** in one view,
  not N views. Frame names give it away: `… | Claude Web |`, `… | Claude App |`, `… | Claude Code |`.
- **Component instances are shared structure** — a repeated instance stamped on every screen is
  authored once as a shared view / reused block sequence.
- **Hidden nodes** (`hidden="true"` in `get_metadata`) are **not** emitted.

## Assets — export, name, group

**Keep the cropped render, not the full source.** Per image node:
`download_assets(fileKey, nodeId, defaultFormat:"png", defaultScale:3)`. The response has an `export`
(the node rendered **as displayed** — cropped/framed) and `rawImages` (the original uploaded fills —
full, uncropped). **Always keep the `export`; discard `rawImages`.** Whenever one node yields a full and
a cropped asset, keep the **cropped**, every time. `curl` it into `assets/` at its CDN-mirroring path.
@3x for retina (inspect returned dims; small icons may not need 3×).

### URLs are probed, never derived (gate)

The wire `url` is **always the full CDN URL**, never a local or relative path. The base today is
`https://cdn.neosapien.xyz/neo/<family>/assets/…` — host, then the **`neo/` app-namespace segment**,
then the family. The S3 key is `public/neo/<family>/assets/…`; the CDN drops `public/`, keeps `neo/`.

**Do not deduce that from the folder.** It does **not** mirror the URL root 1:1, and this exact deduction
shipped wrong **twice** — once missing `assets/`, once missing `neo/` (commit `2b3aad9` rewrote 26 URLs;
every asset 403'd until then). The note read *"**likely** includes assets/… **confirm with user before
finalizing urls**"* — "likely", said confirm, did not confirm, finalized. A rule that says derive a URL
from a folder makes a guess feel like a deduction. **The mapping is host config; you cannot reason your
way to a bucket layout.**

> **Gate** — before handoff, and before trusting any base you did not probe this run:
> `curl -s -o /dev/null -w '%{http_code}' <one real wire URL>` → expect **200**. Not a sanity check; a
> gate (`verify-output.md` §A6). Probe *early*: run after 60 URLs are written, it can only tell you to
> rewrite all 60.

### Open the PNG before you wrap it

Every asset defect the last run shipped lives **inside the bytes** or **between the bytes and the wire**
— the two places a filename check cannot look. Before authoring the block around an asset, read its real
dimensions (the PNG's IHDR chunk: width/height at bytes 16–23) and *look at it*.

**Ratio.** `width/height` must equal the wire `ratio`. A `ratio` that disagrees is a **crop**, and a crop
is a pixel decision wearing a semantic field's clothes. One shipped asset had ~35% dark padding baked in
at the bottom; the run wrote `ratio: 2.0` over an intrinsic 1.297 plus a compensating
`Alignment.topCenter` in `steps.dart` — so every step image in the package now top-crops forever to hide
one bad export. **Re-export at content bounds; never compensate on the wire or in the renderer.**

**Baked decoration.** An asset that already looks finished must be emitted **bare**. Decoration is either
in the pixels or in the theme — **never both**. `hero.png` arrived with headline, body copy, grid texture
*and* border baked in; the run wrapped it in `group emphasis:"high"`, the theme painted a second gradient
+ `gridLine` grid behind it, and the user asked *"why and what is that random outer border stuff around
the grid? whilst the hero.png doesn't have this"*.

| baked in the pixels | then the wire must NOT |
|---|---|
| text | emit a `header`/`text`/`code` carrying that same string — it renders twice, and it isn't translatable; flag it so the designer can re-export text-free |
| grid / texture | wrap it in `group emphasis:"high"` (the theme paints `gridLine`) |
| border / card shape | wrap it in `group`/`card` (the theme paints the surface) |
| gradient fill | request `groupGradient` / `cardGradient` |

The tell, from `neofig`: **a negative inset on an `<img>` means the effect is baked into the asset.** If
the asset has a border and the design's *node tree* has none, the border is in the pixels.

**PII — a human eyeballs every PNG before upload.** The secret scan reads text, the asset verify reads
filenames, the CDN is public and unrecallable: a redacted terminal screenshot went out through that gap.
**Any hand-supplied asset (the user dropping a file in; anything not from `download_assets`) is DECLARED
at handoff** with its source — the moment a human can ask whether the redaction covers everything.
Mechanical tell: a non-family width (one `1067` among thirty-three `1074`s) and no source node.

## Required add-on manifest — the handoff owes this

`neo_sdui_media` and `neo_sdui_syntax` are **add-on packages that re-register a wire type** (last-wins:
`NeoSdui.compose([…]).registry` folds them over core —
`docs/solutions/architecture-patterns/addon-core-floor-and-last-wins-upgrade.md`). Absent, the type still
resolves — **to the core floor, silently**. Great runtime resilience, catastrophic authoring feedback:
the user twice caught the package not using an add-on it owns. Verified in source: **core `code` never
reads `language`; core `media` never reads `kind`** — no throw, no log, the field is simply inert.
`wire-contract.md` marks these `(add-on)`; that annotation is not a warning.

**So the handoff carries a REQUIRED ADD-ONS manifest** — scan the emitted wire for add-on-only fields,
name what the app must compose in, and what each block degrades to without it:

```dart
// deliverables/mcp/ — REQUIRED ADD-ONS, because mcp.json emits `kind` and `language`:
NeoSdui.compose([neoSduiMediaAddon, neoSduiSyntaxAddon]).registry
```

| wire field | add-on | host composes it | host does not — the silent degrade |
|---|---|---|---|
| `media.kind:"video"` | `neo_sdui_media` | cached image / looping video | `Image.network` on an `.mp4` → `errorBuilder` → **flat grey box forever**; `kind` ignored |
| `code.language` | `neo_sdui_syntax` | highlighted + language badge | plain mono `Text`; `language` never read |

Emitting an add-on field without listing its add-on is the defect, not a footnote. If the app cannot
compose it, don't emit the field — author the floor deliberately and say so.

## Verify

List `assets/` against the wire's `url`s: every referenced URL has a file (`HAVE`), every file is
referenced; name the mismatches. **This is a filename check and nothing more** — it never opens a PNG.
The bytes are covered by *Open the PNG* and by human eyes, or they are not covered at all.
