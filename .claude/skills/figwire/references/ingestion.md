# Ingestion — reading a Figma page

## The ingest matrix — the two projections need different first calls

figwire emits two projections of one read, and they do **not** share an ingest. That is not a
compromise; it is the point.

| projection | first call | why | last resort |
|---|---|---|---|
| **wire** (semantics) | `get_metadata` | the **independent** coverage denominator (`verify-output.md`) — `get_design_context` is the same pass that emits, so it cannot audit itself | screenshot: no independent inventory, so drop-detection downgrades to report-only |
| **theme** (look) | `get_design_context` (+ `get_variable_defs` for the roles that are actually token-bound) | the **only** calls that carry type / fill / effect at all — `get_metadata` returns `id / name / type / x / y / w / h`: no fills, no typography, no effects | screenshot: every role it feeds is `provenance:"inferred"`, which **fails the compile** (`theme-extract.md`) |

**Reading `get_metadata` and then writing a look value is the defect this matrix exists to
prevent.** It shipped a theme with 26 of 29 roles eyeballed off a screenshot — on the happy path,
MCP fully available, because only 3 roles were variable-bound and the rest fell through to the degrade.

Also on the theme path: `get_shader_fill` / `get_shader_effect` for the gradient fills behind
`cardGradient` / `groupGradient` / `accentGradient`. `get_screenshot` is visual truth for
classification and accent detection — never for a number.

**REST `/nodes` (optional, exact text).** When a `FIGMA_TOKEN` is configured, one call returns the
whole page subtree with exact `characters`:

```bash
curl -s -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/<FILE_KEY>/nodes?ids=<NODE_ID>"
```

The URL's `node-id` uses `-`; the API wants `:` (e.g. `4146-14149` → `4146:14149`). Prefer REST /
`get_design_context` text over vision for any `code`/URL block.

## Reading a look value — the source decides the unit

**Honor the codegen's response hints in priority order**, earlier overriding later: Code Connect
snippet → component documentation link → design annotation → design token → raw hex / absolute
position. That last rung is where you lean on the screenshot, and it is the *last* rung.

- **letterSpacing is a unit trap — name the source, the unit follows.** MCP codegen and REST state
  it in **px** (`tracking-[-0.72px]`), 1:1 with Flutter; a hand-off doc or the Figma UI states a
  **percent** → `px = (percent / 100) * fontSize` (`-4%` @ 18px → `-0.72`). Uniform tracking is
  **not** evidence of a fabrication: this design really does track −4% almost everywhere
  (24/−0.96, 14/−0.56, 13/−0.52, 12/−0.48), and a detector built on that theory fired on the two
  roles that were character-exact. Read each role; do not infer one from another, and do not
  "correct" a scale into variety the design does not have.
- **Gradients: always emit explicit `begin` / `end`.** Flutter's `LinearGradient` defaults to
  **horizontal** (`gradient.dart:382`, `begin: centerLeft`); Figma's default handle is **vertical**.
  The defaults disagree, so an omitted `begin`/`end` silently rotates the design 90°.

Deeper conversions — line height, color alpha compositing, gradient handles → `Alignment`, blur σ vs
`BoxShadow.blurRadius`, corners — are in the sibling **user** skill `neofig`
(`~/.claude/skills/neofig/references/figma-mapping.md` §1-§5), **if present** — figwire is a project
skill and may ship without it, so the facts above stand alone. Ignore that file's §6 rate-limit
paragraph ("6 read calls per MONTH"): stale and false, and obeying it re-causes the screenshot
guessing this page forbids.

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
