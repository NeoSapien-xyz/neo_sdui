# Deliverables & assets — where a guide's output lands, and its images

figwire's output is a **deliverable folder** the user reviews and uploads to the CDN as-is: the wire
doc **plus** its image assets, laid out to mirror the CDN. The assets are the *binary* sibling of the
wire — exporting them does **not** break the Iron Rule: the wire still carries only the image **URL
string**, never the bytes or any pixel value. The bytes live in `deliverables/`, never on the wire.

## The deliverable folder

Gitignored. One folder per **guide-family** (`mcp`, `how_to`, …):

```
deliverables/               ← gitignored (CDN staging, never committed)
  mcp/
    mcp.json                ← the ONE wire doc for the whole family
    assets/                 ← uploaded to cdn.neosapien.xyz/neo/mcp/assets/ (S3 key public/neo/mcp/assets/)
      hero.png
      icons/  chatgpt.png  claude.png  connectors.png
      chatgpt/  web-1.png  desktop-1.png  …
      claude/   web-1.png  app-1.png  code-1.png  …
      other/    step-0.png … step-3.png
  how_to/
    how_to.json
    assets/ …
```

- **`deliverables/` is gitignored** — add the line to the repo `.gitignore` if absent.
- **json name = family name** (`mcp.json`, not `mcp_guide.json`).
- **`assets/` mirrors the CDN path** so upload is a straight recursive copy. Wire `url`s must match this layout exactly.

## One JSON per guide-family — not per screen

A family with many Figma pages is **one** wire document, not one-per-page. `views` carry every
sub-screen inside the single doc; the hub navigates to them by name.

- **Root `blocks`** = the family's entry/hub screen.
- **`views`** = every sub-screen (per-client guides, FAQ, troubleshooting), each `{present:"screen", blocks:[…]}`.
- **Shared tail defined ONCE.** A component stamped on every screen (shared FAQ / troubleshooting / use-cases) becomes ONE view, referenced by `screen:<id>` from each client view — never re-embedded per screen.

**Why one doc:** Remote Config's only size limit is **1,000,000 chars total across the whole
project's parameter values** (no per-value cap; 3000 params max). A whole family expands to ~40–60K
chars — trivially one parameter. Splitting multiplies chars (repeated tails) and adds cross-doc
`route:` wiring.

**When to split (all rare — until then, one doc per family):**
- a single family alone nears hundreds of KB, or
- per-screen lazy-fetch becomes a real need, or
- the shared tail repeats across ≥3 *separate* families — the repo's deferred `defs`/`ref` dedup trigger (`docs/ideation/neo-sdui-pixel-authority-and-wire-economy.md`).

A genuinely **separate** family (`mcp` vs `how_to`) is always its own doc / RC key.

## Multi-frame guides — collapse frames, don't multiply screens

One screen is often several Figma **frames**. Map, don't transcribe 1:1:

- **Tabs are separate frames.** A guide with Web / Desktop / Code tabs is 2–3 frames (one per active tab) → **one `tabs` block** in one view, not N views. Frame names give it away: `… | Claude Web | …`, `… | Claude App | …`, `… | Claude Code | …` = one Claude view, three tabs.
- **Component instances are shared structure.** A repeated instance (`use-cases-FAQs-troubleshooting`, `mcp-guide`, …) stamped on every screen → author once as a shared view / reused block sequence.
- **Hidden nodes** (`hidden="true"` in `get_metadata`) are **not** emitted — off-variants, inactive tab states, unused promo cards.

## Assets — export, name, group

figwire exports the guide's images from Figma so the user can upload them; the wire only names their URL.

**Export — keep the cropped render, not the full source.** For each image node:
`download_assets(fileKey, nodeId, defaultFormat:"png", defaultScale:3)`. The response has an `export`
(the node rendered **as displayed** — the cropped/framed asset) and `rawImages` (the original uploaded
source fills — the **full, uncropped** images). **Always keep the `export` (cropped); discard
`rawImages` (full).** More generally: whenever one node yields a full asset and a cropped asset, keep
the **cropped** every time. `curl` the chosen URL into the guide's `assets/` at its CDN-mirroring path.
@3x for retina mobile (inspect returned dims; small icons may not need 3×).

**Naming & URLs — identical across all three; the CDN url on the wire, never a local path.**
- The asset's **filename and folder path are identical** in `deliverables/<family>/`, on the CDN, and in the wire `url` — **never rename** between them.
- The wire `url` is **always the full CDN URL** — **never** a local or relative path. The base is
  `https://cdn.neosapien.xyz/neo/<family>/assets/…` (verified: host `cdn.neosapien.xyz`, then the
  **`neo/` app-namespace segment**, then the family, then `assets/`). The S3 object key is
  `public/neo/<family>/assets/…`; the CDN drops `public/` but **keeps `neo/`**. So the local folder
  `deliverables/<family>/assets/foo.png` → URL `cdn.neosapien.xyz/neo/<family>/assets/foo.png`.
- The deliverables folder does **not** mirror the URL host-root 1:1 — the CDN prepends `neo/` before
  the family. Drop it and every asset 403s. Only the filename + sub-path under `assets/` are identical.
- Sanity-check before handoff: `curl -s -o /dev/null -w '%{http_code}'` one real wire URL; expect 200.

**Group by role:**

| asset kind | path | why |
|---|---|---|
| hub hero | `assets/hero.png` (flat) | one, top-level |
| client / card icons | `assets/icons/<name>.png` | few, shared on the hub |
| per-step guide screenshots | `assets/<client>/<tab>-<n>.png` | many, client-scoped |

Flat for the few shared images; per-client subfolders for the many step screenshots. Wire `url`s must
match (`…/mcp/hero.png`, `…/mcp/icons/chatgpt.png`, `…/mcp/chatgpt/web-1.png`).

**Baked-text check.** If a hero/image has text baked in (no matching text node in `get_metadata`), do
**not** also emit a `header` for that same text — it renders twice. Emit `media` only, and flag that the
copy lives in the asset (not translatable) so the designer can confirm or re-export text-free.

**Verify.** After export, list `assets/` against the wire's `url`s: every referenced URL has a file
(`HAVE`), every file is referenced. Name the mismatches. (Secret-scan unchanged — URLs only, no keys.)
