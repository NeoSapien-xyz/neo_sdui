---
title: neo_sdui code block + syntax add-on - Plan
type: feat
date: 2026-07-12
topic: neo-sdui-code-block
artifact_contract: ce-unified-plan/v1
artifact_readiness: requirements-only
product_contract_source: ce-brainstorm
execution: code
---

# neo_sdui code block + syntax add-on - Plan

## Goal Capsule

- **Objective:** Give the wire a way to present exact strings the user must reproduce — shell commands, server URLs, config — as monospace, copy-on-tap content, so the MCP guide's commands stop being un-copyable prose.
- **Product authority:** ce-brainstorm (2026-07-12), grounded in the MCP guide wire (`packages/neo_sdui/example/mcp/mcp_document.dart`) and the add-on package catalog ideation (`docs/ideation/2026-07-12-neo-sdui-addon-package-catalog.html`, idea #1).
- **Open blockers:** None. The core `code` block and step-embedded commands (R6) are shipped; one deferred package (`neo_sdui_syntax`) remains — see Scope Boundaries.

## Product Contract

### Summary

A `code` block — monospace content plus a tap-to-copy chip — lives in **core** (zero new dependency; copy via Flutter's `Clipboard`). Syntax coloring is a separate opt-in `neo_sdui_syntax` add-on that re-registers the same `code` type, deferred until wire content actually needs it.

### Key Decisions

- **Floor in core, not a package.** The guide's commands must render out-of-the-box, and copy needs only `flutter/services` (zero dependency), so core owns the `code` block. Mirrors the `media` floor / `neo_sdui_media` enhancer split — core ships a zero-dep floor for every semantic it emits; a heavy add-on upgrades it by re-registering the same type (last-wins).
- **`language` is additive, not reserved now.** The core floor ignores any `language` field; the future `neo_sdui_syntax` add-on reads it to pick a highlighter theme. Because a builder can read any field, adding `language` later needs no wire migration — so it is not reserved up front (YAGNI).
- **Look stays in the theme.** The block reads `theme.mono` (a new type-scale slot), `theme.surface`, and the accent role (`toneSurface('accent')`) — no pixels inlined in the builder, none on the wire. A re-skin recolors the chip with no wire change.

### Requirements

**Shipped (core `code` block)**

- R1. A `code` block renders `content` (required string) in the theme's monospace slot, on the card surface.
- R2. An optional `label` renders as a muted caption above the content.
- R3. Tapping the copy chip writes `content` to the clipboard (`Clipboard.setData`), fires a light haptic, and flips the chip to "Copied" for ~2s.
- R4. The block always renders (it is core) — there is no missing-add-on degrade path for the floor itself.
- R6. A `steps` item may carry an optional `code` field (alongside the optional `detail` sub-line), rendering the same copyable chip under its caption. The MCP setup steps now split their commands out of the caption into `code` (`npm install …`, the server URL, `/mcp`, `claude mcp list`).

**Deferred**

- R5. `neo_sdui_syntax` add-on `copy()`s the registry and re-registers `code` with `flutter_highlight` coloring keyed off `language`; absent the add-on, the core floor renders unchanged.

### Acceptance Examples

- AE1. **Covers R1, R2.** `{ "type": "code", "label": "Your MCP server", "content": "https://api.neosapien.xyz/mcp" }` → "Your MCP server" caption above a mono URL with a Copy chip.
- AE2. **Covers R3.** Tap Copy → clipboard holds the exact `content`; chip reads "Copied", then reverts.

### Scope Boundaries

**Deferred for later**

- `neo_sdui_syntax` (highlighter add-on) — no wire content needs coloring yet; the one config file (`claude_desktop_config.json`) is named in prose, not shown as a code block. Build trigger: a `code` block whose `content` is a multi-line config a reader must scan.

**Outside this feature**

- `neo_sdui_prompt` (tap-to-copy suggested-prompt chips, catalog #7) and `neo_sdui_launcher` (url_launcher, catalog #3) — separate packages.

### Outstanding Questions

**Deferred to planning**

- `neo_sdui_syntax` package layout (own `pubspec`, `flutter_highlight` dependency, theme-keyed highlight theme) — plan when the build trigger fires.

### Sources / Research

- Ideation: `docs/ideation/2026-07-12-neo-sdui-addon-package-catalog.html` (idea #1).
- Wire evidence: `packages/neo_sdui/example/mcp/mcp_document.dart` (commands in `steps` captions; the `code` server-URL block added this session).
- Shipped code: `packages/neo_sdui/lib/src/blocks/code.dart`, registered in `default_registry.dart`; `mono` slot in `lib/src/theme/neo_sdui_theme.dart`; tests in `test/blocks/leaf_blocks_test.dart`.
- Library check (context7, 2026-07-12): `flutter_highlight`/`highlight` is the live highlighting stack; `flutter_markdown` is discontinued (relevant only if `neo_sdui_syntax` folds into a markdown add-on later).
