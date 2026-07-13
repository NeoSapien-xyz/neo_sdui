---
title: "Server-driven UI: the wire carries semantics, the client owns the look"
date: 2026-07-11
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: high
applies_when:
  - Deciding where a guide's visual look (card background, radius, shadow, blur, spacing) lives
  - Two guides must look different but share the same block code
  - Tempted to put a hex, font size, or padding on the Remote Config wire
  - Adding a new block type or a whole new guide
  - Judging whether neo_sdui's SDUI approach matches what large product teams do
tags:
  - server-driven-ui
  - sdui
  - hostconfig
  - theming
  - block-registry
  - airbnb-ghost
  - adaptive-cards
---

# Server-driven UI: the wire carries semantics, the client owns the look

## Context

`neo_sdui` renders a guide from one Remote Config JSON document. A recurring
worry drove this learning: two guides (how_to, the MCP setup guide) must look
different — different card background, corner radius, backdrop blur, spacing —
yet the wire carries no pixels. The instinct is either to author per-feature
widgets or to start sending styles on the wire. Both are wrong. This documents
what Airbnb, DoorDash, and Microsoft's Adaptive Cards actually do, coded and
mapped to our engine, so the architecture is validated rather than guessed.

## Guidance

Every production SDUI system obeys the same three rules; they differ only in
vocabulary:

1. **The client owns a generic, reusable component catalog**, built once — never
   per feature. New features are new *server payloads*, not new client widgets.
2. **The server composes a screen** by naming components + a layout and filling
   their data. It never ships pixels or a widget tree.
3. **The look lives on the client**, in a config object the server can *select
   into* but never *define*. Airbnb calls it the component; Adaptive Cards calls
   it `HostConfig`; we call it `NeoSduiTheme`.

The load-bearing rule: **the look is a client concern the wire can select but
never define.** Concretely, in `neo_sdui`:

- **Vary look across guides** → hand each `NeoSduiView` its own `NeoSduiTheme`.
  Same block code, different palette. It is data, not per-guide code.
- **Enrich look robustness** (radius, shadow, blur, shape) → grow `NeoSduiTheme`
  (the HostConfig), never the wire. This is exactly Adaptive Cards' `containerStyles`.
- **One-off bespoke look** → register a custom builder
  (`registry.register('cta', myNeumorphicCta)`), the client-owned component escape
  hatch. Not a wire field.
- The wire carries only **semantic tokens**: `emphasis` (high/normal/low), `tone`
  (default/accent/critical), and named variants like `variant:"tile"`.

## Why This Matters

- **The `neo_ui` swap stays a one-object change.** All pixels live in one
  `NeoSduiTheme`; when the design system lands it rebuilds that object with the
  same wire.
- **Adding a guide is JSON-only.** A new guide reusing an existing look ships
  from Remote Config with no app release.
- **It prevents the leak DoorDash regretted** — a raw `Struct` fallback that
  "shouldn't be needed in most cases" and leaked pixels into the wire. No hex,
  font size, or padding on our wire, ever.
- **It is the industry-proven shape**, not a local invention — the same loop as
  Airbnb Ghost, DoorDash, and Adaptive Cards.

## When to Apply

- Any time a look difference between guides comes up — reach for a second theme,
  not a second widget or a wire style.
- Before adding a field to the wire — if it is a pixel (hex/size/padding), stop;
  it belongs in `NeoSduiTheme`.
- When a design needs a treatment the theme cannot express — grow the theme, or
  register a custom builder; never send the treatment as data.

## Examples

### Airbnb Ghost — Section / SectionComponent / Layout → our registry

Server sends **sections** (data) + a **layout**; the client maps each section to
a **SectionComponent** it already owns. Sections are *"entirely independent of
the screen on which they are displayed"* — reusable across every feature.

```kotlin
// SERVER (data + type names only):
Screen(layout = SingleColumnLayout(["title", "cta"]),
       sections = mapOf(
         "title" to TitleSection("Beach house", componentType = PLUS_TITLE),
         "cta"   to ButtonSection("Reserve", action = Reserve)))
// CLIENT owns the catalog; the server only NAMES which component:
val registry = mapOf(PLUS_TITLE to PlusTitleComponent(), DEFAULT_TITLE to DefaultTitleComponent())
layout.placements.forEach { addToLayout(registry[sections[it].componentType].build(sections[it])) }
```

```dart
// neo_sdui — the same loop (NeoSduiView._buildBlocks):
for (final node in document.blocks) {
  out.add(registry.builderFor(node.type)!(context, node)); // client turns data -> pixels
}
```

`SectionComponentType -> SectionComponent` **is** our `type -> BlockBuilder`
registry. `PLUS_TITLE` selecting a Plus-branded look **is** our `tone:"accent"`
selecting the accent role — a *named* variant the client owns, never a hex.

### DoorDash — generic components + layout engine → our layout primitives

DoorDash's pain was feature-coupled components: *"client-side components that
looked very similar were difficult to reuse."* Fix: generic Lego-block components
+ a layout engine, so *"most client-side code can now be reused"* and pages ship
by backend deploy. Our `row`/`column`/`group` are that layout engine — structure
only, spacing/surface from the theme:

```json
{ "type": "group", "children": [
    { "type": "card", "variant": "tile", "thumb": "..." },
    { "type": "row", "children": [ { "type": "card" }, { "type": "card" } ] } ] }
```

One generic `card` serves how_to's image-top tile, the MCP picker row, and footer
nav by *field presence* (`variant`, `thumb`, `subtitle`).

### Adaptive Cards — HostConfig is the theme (this is us, exactly)

The card names semantic tokens (`size`, `color`, `style`); the pixels live in a
client-side `HostConfig`. `NeoSduiTheme` **is** `HostConfig` — including the card
surface treatment the client passes until `neo_ui` exists:

```dart
// WIRE — semantic only:
{ "type": "card", "variant": "tile", "thumb": "...", "action": "sheet:control" }

// THEME (HostConfig) — pixels, client-owned, off the wire:
NeoSduiTheme(
  accent: primary500, onSurface: white, title: workSans24,   // foregroundColors / fontSizes
  cardColor: Color(0xFF202423),                                // containerStyles:
  cardShape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(16)),
  cardShadow: [BoxShadow(color: Color(0x0AFFFFFF), blurRadius: 10)],
  cardPadding: EdgeInsets.all(18), backdropBlur: 0,
  spaceMd: 16, blockSpacing: 24)                               // spacing
```

Adding `cardShape`/`cardShadow`/`backdropBlur` to the theme is not scope creep —
it is literally growing `containerStyles`. A second guide with a different card
look is a second `NeoSduiTheme`, one object, not a line of new widget code.

### Verdict

| Concern | Conglomerate answer | neo_sdui |
|---|---|---|
| Component catalog | generic, built once | `defaultRegistry()` roster |
| Compose a screen | server names components + layout | `blocks` + `views` + `row/column/group` |
| Per-feature difference | server payload, not client code | one JSON document per guide |
| The look | client HostConfig / component, never wire pixels | `NeoSduiTheme`, off-wire |
| Robust look (radius/shadow/blur) | grow `HostConfig.containerStyles` | grow `NeoSduiTheme` card treatment |
| Exact one-off look | client-owned component variant | `registry.register(type, builder)` |
| Escape hatch we refuse | DoorDash's raw `Struct` (leaked pixels) | no hex/size/padding on the wire |

The invariant every one enforces — the look is a client concern the wire can
select but never define — is the exact line `neo_sdui` draws. Enriching the theme
moves *with* that grain. Putting a radius or hex on the wire is the day we leave
the pattern.

## Motion and transitions are the same client-owned concern

Motion follows the identical rule, and it is where the pattern is most tempting to
break. `NeoSduiTheme` carries the motion tokens — `motionDuration`, `motionCurve`,
`reduceMotion` — and every bounded animation (the `faq` accordion, the image
fade-in, the `tabs` switch) derives from them, so two guides animate at their own
pace by being handed different themes, never different wire. A view's *destination*
is on the wire (`action:"screen:x"`, `views.x.present: sheet|screen`); the
*animation* of that push is the app's `Navigator`/route.

The hard line: the wire may name a **motion intent** — a semantic role, the same
species as `tone`/`emphasis`/`present` (e.g. a future `transition:"slideUp"`) —
but it must never carry the animation *itself*: durations, curves, or physics.
This is not a local preference. `rfw` (Flutter's own Remote Flutter Widgets),
under **Limitations**, is explicit: *"you don't want to use RFW to create a UI
that involves page transitions… changing how navigation works in an application…
are all changes that are best made in Flutter itself."* The browser's View
Transitions model draws the same line — the source describes *what a state is*,
the client owns *how it animates between states*. So a transition **role** on the
wire is legal (the client resolves it to real pixels); a transition **definition**
on the wire is the rejected path (see `docs/ideation/neo-sdui-pixel-authority-and-wire-economy.md`
§ "Page transitions — RESOLVED").

## Related

- Plan: `docs/plans/2026-07-11-001-feat-neo-sdui-unified-guide-engine-plan.md`
  (KTD11 role palette + derived look; R22/R23 no per-guide wire presets).
- Ideation: `docs/ideation/neo-sdui-pixel-authority-and-wire-economy.md`
  (the "layered middle" — tokens on the wire, pixels client-side).
## References — the prior art this pattern draws from

`neo_sdui`'s "wire carries semantics, client owns look and motion" line is the
industry-standard SDUI shape, not a local invention. The source behind each
decision:

- **Microsoft Adaptive Cards — HostConfig.** The client-side styling object a card
  selects into but never defines; `NeoSduiTheme` is its analog (role colors,
  type/spacing scales, and `containerStyles` ↔ the card surface treatment).
  <https://learn.microsoft.com/en-us/adaptive-cards/rendering-cards/host-config>
- **Microsoft Adaptive Cards — element schema (semantic tokens).** Cards name
  `size`/`color`/`style` tokens while pixels live in HostConfig — the model for
  `tone`/`emphasis`/`variant` on our wire.
  <https://learn.microsoft.com/en-us/adaptive-cards/schema-explorer/adaptive-card>
- **Airbnb — Ghost Platform (server-driven UI).** The server sends sections + a
  layout that *name* client-owned components; the client owns the component
  catalog — our `type → BlockBuilder` registry.
  <https://medium.com/airbnb-engineering/a-deep-dive-into-airbnbs-server-driven-ui-system-842244c5f5>
- **DoorDash — generic, server-driven UI components.** Generic components + a
  layout engine so pages ship by backend deploy; their regretted raw-`Struct`
  pixel leak is the anti-pattern we refuse (no hex/size/padding on the wire).
  <https://careersatdoordash.com/blog/improving-development-velocity-with-generic-server-driven-ui-components/>
- **Flutter — Remote Flutter Widgets (`rfw`).** Its Limitations section is the
  source for keeping page transitions, gestures, and custom painters off the wire
  and in Flutter itself.
  <https://pub.dev/packages/rfw>
- **Browser — View Transitions API.** Same philosophy for motion: the source
  describes the state, the client owns the transition between states.
  <https://developer.chrome.com/blog/astro-view-transitions>
