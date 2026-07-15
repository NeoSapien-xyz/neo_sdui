# neo_sdui

Server-driven UI for Neo — a Firebase Remote Config JSON document becomes baked,
themed Flutter widgets for pure-content screens (guides, walkthroughs, FAQs).

The governing rule (the **Iron Rule**): the wire carries only *semantics* — what a
thing is and its content — never *look*. No hex, pixel sizes, fonts, or gradients
on the wire. A client-owned `NeoSduiTheme` resolves every look decision, so two
guides differ only by the theme data each view is handed, not by shipping
different block code or different wire pixels.

## Layout

Melos monorepo (`packages/*`):

| Package | What it is |
|---|---|
| [`neo_sdui`](packages/neo_sdui) | Core. Renders a `{version, blocks, views}` wire document; resilient by design — a bad block degrades to a fallback, never crashes the view. Zero heavy deps (`flutter` + `meta`). |
| [`neo_sdui_media`](packages/neo_sdui_media) | Add-on. One media block that infers image vs video from the URL, plays video, and disk-caches both. |
| [`neo_sdui_syntax`](packages/neo_sdui_syntax) | Add-on (scaffold). Re-registers the `code` block to syntax-highlight by language; highlighting is a placeholder until `flutter_highlight` is wired. |

Add-ons compose into the core via `NeoSdui.compose([...])`, re-registering an
existing block `type` (last-wins) so a build without a given add-on degrades to
the core floor instead of breaking.

## figwire skill

[`.claude/skills/figwire`](.claude/skills/figwire) turns any Figma selection into
neo_sdui wire JSON, and its **theme companion** forks that same single read into a
persistent *role ledger* that compiles to a paste-in `NeoSduiTheme` (base +
per-page `copyWith` overrides). One read, two projections: semantics onto the
wire, look into the theme.

## Docs

- [`CONCEPTS.md`](CONCEPTS.md) — shared domain vocabulary (Wire, Block, Role, Role ledger, …).
- [`docs/solutions/`](docs/solutions) — architecture-pattern and bug learnings.
- [`docs/plans/`](docs/plans), [`docs/ideation/`](docs/ideation) — how each piece was designed.

## Develop

Uses [FVM](https://fvm.app) (Flutter 3.41.4, pinned in `.fvmrc`) and
[Melos](https://melos.invertase.dev).

```sh
fvm flutter pub get
melos bootstrap        # link the workspace
melos run analyze      # analyze every package
melos run test         # test every package
```

Per package: `cd packages/neo_sdui && fvm flutter test`. Some authoring tools are
env-gated tests (e.g. `NEO_WIRE_JSON=… NEO_THEME_LEDGER=…`) that skip on a plain
run so the suite stays green in CI.
