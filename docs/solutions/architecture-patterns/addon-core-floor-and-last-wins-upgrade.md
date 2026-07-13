---
title: "SDUI add-ons: a zero-dep core floor, upgraded by a last-wins re-register"
date: 2026-07-12
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: high
applies_when:
  - Deciding whether a new block or capability belongs in core or in an add-on package
  - A semantic needs a heavy dependency (native plugin, parser, highlighter) that some builds won't carry
  - Tempted to mint a new wire type + capability for what is really an enhanced version of an existing block
  - Adding an add-on that enhances how an existing block renders
  - Worried an add-on will crash the view when it is absent or version-short
tags:
  - server-driven-ui
  - sdui
  - add-on
  - block-registry
  - last-wins
  - compose
  - dependency-layering
---

# SDUI add-ons: a zero-dep core floor, upgraded by a last-wins re-register

## Context

`neo_sdui` core must stay `flutter` + `meta` only, yet guides need heavier
capability: cached images, inline video, syntax highlighting, copy-to-clipboard.
Two questions recur: *where does a capability live* (core vs an add-on that pulls
the dependency), and *how does an add-on enhance a block* without the app
hand-wiring every variant, without minting a new wire type for what is really a
nicer render, and without the view crashing when the add-on is absent. This
learning came out of shipping the `code` block (copy) and scaffolding the
`neo_sdui_syntax` highlighter add-on, generalizing what `neo_sdui_media` already
did.

## Guidance

Layer capability in two rungs, split on the dependency line:

1. **Core ships a zero-dependency floor for every semantic it emits on the wire.**
   The floor renders something correct with only `flutter` + `meta`. `code` →
   monospace + copy via `Clipboard.setData` (`flutter/services`, no package).
   `media` → `Image.network`. If the wire can name it, core can render *a* version
   of it.

2. **A heavy variant is an opt-in add-on package that re-registers the same wire
   `type`.** The add-on pulls the dependency and calls `register(type, builder)` —
   which is **last-wins** in `BlockRegistry` — so it *replaces* the core builder
   for that type. It does **not** mint a new wire type or a new capability for an
   enhancement. `neo_sdui_syntax` re-registers `code`; `neo_sdui_media`
   re-registers `media`.

3. **Compose folds add-ons in; absence degrades to the floor.**
   `NeoSdui.compose([addon]).registry` merges the add-on's builders over core.
   When the add-on is not composed in, the type still resolves — to the core
   floor. The view degrades, it does not crash. A pure enhancement therefore needs
   no `requires`/`fallback` on the wire (the type always resolves to *some*
   builder).

4. **Split at the dependency line, not the feature line.** The zero-dep part of a
   feature belongs in core; only the dependency-bearing part is the package. Copy
   is zero-dep → core. Highlighting needs `flutter_highlight` → the add-on. So the
   "code add-on" is really *core `code` + `neo_sdui_syntax`*, not one package.

5. **Reserve new wire types for genuinely new semantics** (charts, maps), never
   for "a nicer version of X." The test: could core render a plausible floor for
   it? If yes, it is the same semantic — re-register, don't add a type.

Rule of thumb: **needs a dependency core refuses → add-on that re-registers the
type; renders fine on `flutter` + `meta` → core floor.**

## Why This Matters

- **Resilience is structural.** An absent or version-short add-on degrades to the
  floor — never a blank box, never a crash. The `type → builder` map always
  resolves.
- **No capability drift.** Registration *is* the capability declaration (compose
  derives the capability map from the same add-on that registers the builder), so
  "registered a block but forgot to declare its capability" can't happen.
- **No speculative packages.** The cheapest add-on rung — replace one block's
  implementation — needs zero new machinery. You never mint a type + capability
  just to get a richer render.
- **Core stays `flutter` + `meta`.** The heavy dependency stays opt-in to the
  builds that actually want it; a guide that needs neither video nor highlighting
  ships neither.

## When to Apply

- **Before adding a block that needs a heavy dependency** — put the zero-dep floor
  in `defaultRegistry()`, put the dependency in an add-on package that
  re-registers the type.
- **Before minting a new wire `type`** — ask "new semantic, or nicer render of an
  existing one?" Nicer render → re-register the existing type; new semantic → new
  type.
- **When an add-on might be missing** — lean on last-wins degrade for pure
  enhancements; the core floor covers absence with no wire ceremony.

## Examples

### code — copy floor in core, highlighting in `neo_sdui_syntax`

```dart
// CORE (packages/neo_sdui) — zero-dep floor, always present:
BlockRegistry defaultRegistry() => BlockRegistry.empty()
  ..register('code', buildCode);   // mono + Clipboard.setData, no package

// ADD-ON (packages/neo_sdui_syntax) — re-registers the SAME type, last wins:
final neoSduiSyntaxAddon = NeoSduiAddon(
  name: 'neo_sdui_syntax',
  blocks: {'code': buildSyntaxCode}, // pulls flutter_highlight; no new type
);
```

```dart
// Install is composition; absence degrades to the core floor, no crash:
final withHighlight = NeoSdui.compose([neoSduiSyntaxAddon]).registry;
final coreOnly      = NeoSdui.compose(const []).registry;
// both resolve 'code' — one to buildSyntaxCode, one to buildCode.
```

### media — `Image.network` floor in core, video/caching in `neo_sdui_media`

Same shape: core `media` renders `Image.network`; `neo_sdui_media` re-registers
`media` to infer image-vs-video from the URL, play video, and disk-cache both. A
guide without the add-on still shows the image.

### The escape hatch this generalizes

`sdui-look-is-client-owned.md` names `registry.register(type, builder)` as the
one-off "client-owned component" escape hatch for a bespoke *look*. This learning
is the packaged, dependency-driven form of that same seam: an add-on is a
last-wins re-register that also carries a dependency and ships as its own package.

## Related

- Sibling pattern: `docs/solutions/architecture-patterns/sdui-look-is-client-owned.md`
  (where the *look* lives — theme vs wire; this doc is where *capability* lives —
  core vs add-on).
- Plan: `docs/plans/2026-07-12-001-feat-neo-sdui-code-block-plan.md` (the `code`
  block floor + deferred `neo_sdui_syntax`).
- Ideation: `docs/ideation/2026-07-12-neo-sdui-addon-package-catalog.html` (idea #3,
  "the image add-on is a last-wins swap, not a new type").
- Compose spine: `packages/neo_sdui/lib/src/compose/` (`NeoSduiAddon`, `neo_compose.dart`).

## References — the prior art this pattern draws from

- **Microsoft Adaptive Cards — `fallback` / `requires` / `version`.** An element
  declares a minimum feature version and an alternate subtree the host renders
  when it can't satisfy the requirement; when nothing satisfies and no fallback
  exists, the element is dropped. This is the model for our `requires`/`fallback`
  degrade and the core-floor guarantee beneath an absent add-on.
  <https://learn.microsoft.com/en-us/adaptive-cards/schema-explorer/adaptive-card>
- **Flutter — Remote Flutter Widgets (`rfw`).** rfw builds UIs from *prebuilt*
  components and directs genuinely new widgets to Flutter itself, not the remote
  payload — the reasoning behind an add-on being a Dart package that re-registers a
  `type`, never a remote widget tree.
  <https://pub.dev/packages/rfw>
