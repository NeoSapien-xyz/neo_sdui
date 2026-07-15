# Ingestion — reading a Figma page

MCP-first: read the node with the Figma MCP calls below. Degrade to a screenshot only
when the MCP is unavailable or a call fails.

## Paths, in order of preference

1. **Figma MCP (primary).** For the target page node:
   - `get_metadata` — the structural node inventory (id / name / type / x / y / w / h). This is the
     **coverage denominator** (see `verify-output.md`): the independent "seen" set. Get it first.
   - `get_screenshot` — the visual truth for classification and accent detection.
   - `get_design_context` — consult for **exact text strings** (it returns React/Tailwind code; read
     the string literals out of it, ignore the component decisions).
   - `get_variable_defs` — bound color/number/type **variables** and styles: the source of truth for
     the *look projection* (the theme), not the wire. Prefer over reading pixels. Look-only — see
     `theme-extract.md`.
   - `get_shader_fill` / `get_shader_effect` — gradient fills for the theme's
     `cardGradient`/`groupGradient`/`accentGradient`. Look projection only, never the wire.
2. **REST `/nodes` (optional, exact text).** When a `FIGMA_TOKEN` is configured, one call returns the
   whole page subtree with exact `characters`:
   ```bash
   curl -s -H "X-Figma-Token: $FIGMA_TOKEN" \
     "https://api.figma.com/v1/files/<FILE_KEY>/nodes?ids=<NODE_ID>"
   ```
   The URL's `node-id` uses `-`; the API wants `:` (e.g. `4146-14149` → `4146:14149`). Prefer REST/
   `get_design_context` text over vision for any `code`/URL block.
3. **Pasted / exported screenshot (degrade).** When the MCP is unavailable or a call fails, work
   from a screenshot the user pastes/exports. The skill must still produce a validated document —
   but on this path there is **no independent inventory** and **no exact text**, so drop-detection is
   downgraded (report-only) and `code`/URL text is vision-inferred and flagged low-confidence.

## Token handling (security)

The `FIGMA_TOKEN` is supplied **only** via an environment variable, is gitignored, and is **never**
hardcoded, committed, or written to logs, the coverage report, or error output. Do not echo the
token or full request/response headers.

## Exact-text rule for `code`/URL blocks

`code` block `content` and any URL are meant to be **copied verbatim**. Source them from an exact-text
path (`get_design_context` string literals or REST `characters`). On the screenshot-only path they are
vision-inferred — emit them but mark them **low-confidence** in the coverage report so the human
verifies character-by-character. A page containing `code`/URL blocks should use an exact-text pass.

## If a call fails

If a Figma call 403s, suspect the **wrong account** first (the Figma identity may be `@neosapien.ai`,
not the `@neosapien.xyz` used elsewhere), then the node id.

## Assets and multi-frame guides

Reading is not the whole ingest. A guide-family spans several frames, and its images must be exported
(not just referenced) so the user can upload them to the CDN. `download_assets` (the export call) and
the frame-collapse / asset-grouping rules live in `deliverables-and-assets.md`. Only the main thread
can read the Figma MCP — subagents cannot auth it, so pull every frame, screenshot, and asset yourself.
