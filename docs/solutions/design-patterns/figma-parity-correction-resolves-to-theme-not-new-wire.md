---
title: Figma-parity corrections resolve to a theme value or a run token, not a new wire construct
date: 2026-07-17
category: design-patterns
module: neo_sdui / figwire (server-driven UI)
problem_type: design_pattern
component: tooling
severity: medium
applies_when:
  - A rendered SDUI screen does not match a design and the instinct is "I need a new block, flag, or widget"
  - An authoring gate (baked_type, role_slots_complete, role_lint) blocks a shortcut
  - Adding a new wire tone, icon, or run treatment to match a specific Figma pixel
related_components:
  - testing_framework
  - documentation
tags:
  - figma-parity
  - server-driven-ui
  - look-is-client-owned
  - theme-tokens
  - wire-vs-theme
  - triage
  - design-system
  - no-look-on-the-wire
---

# Figma-parity corrections resolve to a theme value or a run token, not a new wire construct

## Context

`neo_sdui` renders a server-driven UI (SDUI) "MCP setup guide" from a wire JSON (`deliverables/mcp/mcp.json`, shipped via Firebase Remote Config `guide_mcp`) into a `NeoSduiView`, themed by a `NeoSduiTheme` the consuming app supplies. The project's IRON RULE is already documented (see [sdui-look-is-client-owned](../architecture-patterns/sdui-look-is-client-owned.md)): the wire carries **only semantics + role tokens** (block types, tones like `accent`/`strong`, icon names) — never hex, px, font, gradient, or shadow values. All LOOK lives in `NeoSduiTheme`; MOTION is a theme-gated package idiom with a `reduceMotion` kill switch.

Bringing that guide to pixel-parity with a Figma design took ~44h of small visual corrections, screen by screen. Across those corrections one reflex-failure recurred: under parity pressure — "this *exact* pixel is wrong" — the tempting move was always to add a new wire construct (a new block type, a per-element flag, a widget, an addon invocation). The correct move was almost always smaller. This learning captures the triage that prevents the reflex. The three-home taxonomy itself is defined in the parent doc; this doc is that taxonomy *applied under pressure*, plus the cautionary reversal.

## Guidance

When a specific Figma pixel is off, **classify the element's home BEFORE writing any code.** A "custom Figma element" has exactly three possible homes:

- **look → theme** — a color / gradient / shadow / font value, or a semantic tone/role. Put it in `NeoSduiTheme`.
- **composition → existing wire blocks** — arrange blocks you already have (a callout is a card; a group is a container).
- **genuinely-new-kind → registry addon** — a real new block type. Rare.

Under parity pressure the answer is almost always the first one: the difference dissolves into a theme value, or at most a tiny reusable **run-level token** (a one-flag opt-in on the existing text-run system). The reusable rule: *no look on the wire → the fix is a theme value or a one-flag run token roughly 90% of the time.* Resist the new block/widget/addon until you have ruled out the first two homes.

## Why This Matters

Skipping the triage costs rework and permanent wire bloat. The canonical case shipped a whole code-block construct — nested `{"type":"code"}` blocks through the `neoSduiSyntaxAddon` (flutter_highlight) plus a Copy chip — for what was visually just "some words in a mono font." That had to be torn back out.

The deeper cost is contractual. The whole point of SDUI is that **the same wire re-themes per client**: look is client-owned data, so a future `neo_ui` can rebuild the palette and every existing wire re-skins for free. Every hard-coded construct — a bespoke widget, a per-element flag encoding a pixel, a copy chip — erodes that. It moves look back onto the wire, freezes one client's rendering into the contract, and forbids the re-theme. Keeping look off the wire is what preserves the SDUI contract; the triage is how you keep it off.

## When to Apply

- Whenever a rendered SDUI screen doesn't match a design and the instinct is "I need a new block / flag / widget." Stop and run the three-homes triage first.
- Whenever an **authoring gate blocks you**. The gates are signals, not obstacles (see [authoring-wire-needs-strict-vocabulary-gate](../architecture-patterns/authoring-wire-needs-strict-vocabulary-gate.md)):
  - `baked_type_test` forbids `theme.<textRole>.copyWith(fontSize/letterSpacing/fontFamily:)` unless marked `// geometry:`. Tripping it means "add a *role*, don't bake a value."
  - `role_slots_complete_test` requires every `NeoSduiTheme` ctor param be registered in `kRoleSlots`.
  - `role_lint` requires wire icon names resolve to `kDefaultIcons`, `kDrawnIcons`, or a named theme icon.

A blocked gate is telling you the change belongs in the theme as a named role. Add the role.

## Examples

### Canonical: the copy-chip reversal

Figma showed inline shell commands mid-sentence in captions (`/mcp`, `claude mcp list`, `claude mcp get neosapien`) in grey IBM Plex Mono.

- **Wrong instinct:** "these are code" → reach for the big hammer: nested `{"type":"code"}` wire blocks rendered through the composed `neoSduiSyntaxAddon`, with a **Copy chip**. A whole code-block construct on the wire for words in a mono font.
- **User hard-rejected:** "REMOVE THAT COPY CHIP!!! ... just use the ibm plex mono whatever font with the different color it has."
- **Correct home (look → run token):** a tiny `mono` **run flag** in the existing text-run system. A caption run becomes `{"text":"claude mcp list","mono":true}` and renders in `theme.mono` — inline, flat, never gradient-shaded. No new block type, no widget, no addon. ~15 lines in `_gradient_text.dart` (commit `4f66050`). The syntax addon still exists and stays composed for genuine multi-line code (the hero `claude mcp add` promo); the MCP wire just no longer abuses it for inline commands.

The `mono` run resolves to a theme slot and is deliberately excluded from accent/gradient resolution:

```dart
// _gradient_text.dart — parse: a run opts in via "mono": true on the wire
_Run(e['text'] as String, e['tone'] as String?, mono: e['mono'] == true)

// resolve: a mono run rides theme.mono, recolored only by an explicit tone
TextStyle _monoStyle(NeoSduiTheme theme, String? tone) {
  final a = theme.accentFor(tone);
  return a == null ? theme.mono : theme.mono.copyWith(color: a.color);
}
```

### The other six fixes — each resolved to a theme value or role, not a new wire construct

| Figma pixel off | Wrong instinct | Correct home |
| --- | --- | --- |
| "from NeoSapien" gradient too sharp | a per-run "no-gradient" flag | new built-in tone `accentFlat` = `NeoAccent(accent)` (flat green, no `accentGradient`) in `kBuiltinAccentTones` + `accentFor` |
| "Add those tasks to my Notion." should be white | hardcode a hex on the run | new built-in tone `strong` = `NeoAccent(textPrimary)` — a semantic tone, not a color |
| picker/step cards need a visible shadow | a wire "elevated" flag | theme `cardShadow` value change (4%-white glow → `0x2E000000 / blur 14 / y+4`); pure theme, no wire touch |
| "Requires laptop" callout gradient wrong | a new callout block type | callout-as-**card** (composition: `radiusMd→radiusLg`, `spaceMd→cardPadding`) + theme `cardGradient` diagonal `Alignment(-0.41,-0.91)→(0.41,0.91)` (~156°) |
| star icon wrong glyph / too small | swap the app's Material icon set | package-**drawn** `NeoSparkleIcon` (CustomPaint) registered in `kDrawnIcons`, removed from `kDefaultIcons` — `leadingIcon` resolves theme icons first (app override wins), then `kDrawnIcons`; no app icon-set change |
| hero command baked `fontSize` tripped `baked_type` | `theme.mono.copyWith(fontSize: 15)` | new `commandStyle` `TextStyle?` role (15px/+0.6 lives as a role, not a bake); registered in `kRoleSlots` + `theme_compile` |

### The `commandStyle` role — dodging the `baked_type` gate

The hero command card needed a notch-larger mono than inline `mono`. Baking it (`theme.mono.copyWith(fontSize: 15)`) trips `baked_type_test`. The gate's real message: make it a role. A nullable role with a `mono` fallback keeps the size reachable from the theme and byte-stable for themes that set nothing:

```dart
// neo_sdui_theme.dart
final TextStyle? commandStyle;               // ctor param, registered in kRoleSlots
TextStyle get resolvedCommandStyle => commandStyle ?? mono;
```

### Motion corrections (same principle, theme-gated idiom)

Two motion fixes stayed inside the package's motion idiom rather than becoming wire flags: the pinned Web/Desktop/Code tab strip now **SwapFades** its content on tab change (was a hard cut — the pinned-tab-swap bug), and step images **shimmer + cross-fade into a reserved ratio box** via the shared `neoNetworkImage` core (`_media_frame.dart`) instead of jumping from `SizedBox.shrink` to `AspectRatio`. Both are gated by the theme and killed by `reduceMotion` (see [motion-is-look-client-owned-tokens-package-idiom](../architecture-patterns/motion-is-look-client-owned-tokens-package-idiom.md)).

## Related

- [sdui-look-is-client-owned](../architecture-patterns/sdui-look-is-client-owned.md) — the parent principle; defines the three-homes taxonomy (look→theme / composition→wire / new-kind→registry). This doc is that taxonomy applied under parity pressure, plus the copy-chip cautionary reversal it lacks.
- [accent-text-gradient-theme-owned](../architecture-patterns/accent-text-gradient-theme-owned.md) — the string-or-runs `neoText` mechanism this session extended; `accentFlat`, `strong`, and the `mono` flag are new run tones/treatments alongside `accent`.
- [addon-core-floor-and-last-wins-upgrade](../architecture-patterns/addon-core-floor-and-last-wins-upgrade.md) — governs `neoSduiSyntaxAddon`, the registry home the wrong first attempt reached for; the negative example of the third home.
- [vary-block-by-render-context-not-wire-flags](../architecture-patterns/vary-block-by-render-context-not-wire-flags.md) — sibling applied-discipline doc for the composition home; same "resist the wire flag" reflex on a different axis.
- [authoring-wire-needs-strict-vocabulary-gate](../architecture-patterns/authoring-wire-needs-strict-vocabulary-gate.md) — the gates (`baked_type`, `role_slots_complete`, `role_lint`) that push each element into its correct home.
- [one-figma-read-forks-into-wire-and-accumulating-role-ledger](../architecture-patterns/one-figma-read-forks-into-wire-and-accumulating-role-ledger.md) — where the new tones/roles (`accentFlat`, `strong`, `commandStyle`, `kDrawnIcons`) get recorded as they compile into the theme.
- [motion-is-look-client-owned-tokens-package-idiom](../architecture-patterns/motion-is-look-client-owned-tokens-package-idiom.md) — governs the session's motion corrections and the three-deploy-gate taxonomy (cold rebuild / RC republish / CDN) these fixes traverse.
