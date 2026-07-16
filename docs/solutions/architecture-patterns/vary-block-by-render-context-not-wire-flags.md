---
title: "Vary a block by render context and content shape, not per-instance wire flags"
date: 2026-07-16
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: high
applies_when:
  - A single block type must render at different scales or shapes depending on nesting or position
  - Tempted to add a wire or config flag whose only job is to select a rendering variant
  - Server-driven UI over a latent transport (Remote Config, feature flags) where a freshly published flag has not reached the device
  - Deciding whether a rendering difference is content (belongs on the wire) or structure (derivable from the tree)
tags:
  - server-driven-ui
  - sdui
  - block-registry
  - inherited-widget
  - render-context
  - remote-config
  - content-shape
---

# Vary a block by render context and content shape, not per-instance wire flags

## Context

`neo_sdui` renders a server-driven "MCP setup guide" from a Remote Config wire JSON. The wire carries semantics only — block types, text, icons, urls — never look values; the client owns the look via a `NeoSduiTheme`. Bringing the guide's blocks to a Figma design surfaced the same problem twice: **one block type had to render differently depending on where it sat in the tree**, not on anything intrinsic to its content.

The naive instinct both times was to reach for the wire: add a per-instance flag that selects the rendering variant. Two examples:

- A top-level `header` is a 24px section title. The *same* `header` block nested inside a `group` card (the "Here's what it does" use-case rows) must render at ~15px item scale. First instinct: add `level:"item"` to every use-case header. That is ~28 wire edits across screens, a Remote Config re-publish, and it encodes a positional/structural fact as if it were content.
- Troubleshooting/FAQ entries must render as flat `icon + label + chevron` rows inside one shared card — not as nested cards (card-in-card). First cut gated list mode only on `variant:"list"`. It passed tests, then failed on-device: the published flag hadn't reached the device yet (see below).

Both first cuts treated a rendering concern as new wire content. Neither element actually carried new information — the difference was entirely *where* the block sat and *what shape* its neighbors were.

## Guidance

Derive the variation from the tree, not from a per-instance flag. Two levers:

1. **Render context** — an `InheritedWidget` the container block pushes over its children. The child reads it and picks its own look. This is a document-outline rule: nesting sets the heading level, exactly like HTML `<h1>` inside a `<section>`. One general mechanism, zero per-guide widget code.

   - `group` pushes `HeadingScale(compact: true)` over its children.
   - `header` reads `HeadingScale.of(context)` and chooses `theme.title` vs `theme.body`. No `level:` field on any header.

2. **Content shape** — what the children already are. A `group` enters list mode when `variant:"list"` is set OR when **every child is a `card`**. A listed `card` (signalled by a `CardListed` InheritedWidget the group pushes) drops its own surface and renders a compact row.

Reserve wire fields for genuine content the server must supply — text, icons, urls, gradients. A field whose only job is to select a rendering variant is a smell; the tree already knows.

## Why This Matters

The content-shape trigger is the compounding payoff, and it comes from a property of the transport. The device reads the wire from Firebase Remote Config, whose `minimumFetchInterval` is 1 day. A newly added wire flag (`variant:"list"`) is **invisible on the device until it re-fetches** — a reinstall or a realtime update. During this session the nav repeatedly rendered wrong (huge spacing, no list) purely because the device was serving a stale cached wire without the new flag. That looked exactly like "the code is broken." It wasn't.

Auto-detecting list mode from the children's shape means the structural layout renders correctly **the instant the code deploys** (a hot restart), with zero dependence on any wire flag having propagated. Wire *content* still needs the re-fetch — the icons and gradient text won't appear until the device pulls the new wire — but structural layout degrades gracefully from a stale wire instead of breaking.

The general principle: in server-driven UI over a latent transport, structural rendering should be recoverable from data the device already holds. Anything you gate solely on a freshly published flag is a landmine that detonates as a false "broken" signal on every device running yesterday's cache.

The rejected alternatives are instructive. `level:"item"` on 28 headers would have shipped churn and an RC re-publish to express a fact the nesting already states. The `variant:"list"`-only gate looked correct in tests precisely because tests don't have a stale RC cache — the environment that would expose the flaw was absent from the test.

## When to Apply

- A single block/component must render at different scales or shapes depending on nesting or position.
- You are tempted to add a wire/config flag whose only job is to select a rendering variant.
- Server-driven UI where the config wire propagates with latency (Remote Config, feature flags): structural rendering should degrade gracefully from a stale wire, deriving layout from content shape where possible.

Do **not** apply when the variation is genuinely new content the server must supply — text, icons, urls, colors. Those legitimately ride the wire and accept the propagation latency.

A related same-session mechanism in the same spirit: theme-gated nullable roles. `stepCardColor` gates whether steps render as cards; `null` yields byte-identical prior behavior. Variation via theme-role presence, again not per-guide code.

## Examples

Render context — the container pushes an `InheritedWidget`, the child reads it:

```dart
// pushed by the container block (`group`) over its children
class HeadingScale extends InheritedWidget {
  const HeadingScale({required this.compact, required super.child});
  final bool compact;
  static bool of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<HeadingScale>()?.compact ?? false;
  @override
  bool updateShouldNotify(HeadingScale o) => compact != o.compact;
}

// header reads it and picks its own look — no `level:` field on the wire
final compact = HeadingScale.of(context);
final base = compact
    ? theme.body.copyWith(fontWeight: FontWeight.w500)
    : theme.title;
```

Content shape — list mode triggers on the flag OR the children's shape:

```dart
final children = node.nodeList('children');
final allCards = children.isNotEmpty && children.every((c) => c.type == 'card');
if (node.stringOr('variant') == 'list' || allCards) {
  // render one shared list card; listed children drop their own surface
}
```

The `|| allCards` clause is what survives a stale Remote Config cache: the layout is correct the moment the code deploys, before the `variant:"list"` flag has propagated.

## Related

- "Server-driven UI: the wire carries semantics, the client owns the look" — `docs/solutions/architecture-patterns/sdui-look-is-client-owned.md`. Closest kin: it governs *where* look lives (theme vs wire pixels); this doc concretizes its COMPOSITION home into the render-time mechanism for *how* structural/positional variation is derived.
- "Every wire value reaching a widget must pass through guarded typed reads" — `docs/solutions/architecture-patterns/resilient-block-rendering-guarded-typed-reads.md`. Resilience at the read layer; this doc adds a distinct resilience axis (a new wire flag is invisible until re-fetch, so content-shape structure survives where a flag would not).
- "Authoring resilient-runtime SDUI needs a strict vocabulary gate" — `docs/solutions/architecture-patterns/authoring-wire-needs-strict-vocabulary-gate.md`. Adjacent: deriving from context/shape avoids growing the authored vocabulary with a variant-selecting field.
