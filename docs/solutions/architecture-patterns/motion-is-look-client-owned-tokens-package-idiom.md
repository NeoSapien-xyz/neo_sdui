---
title: "Motion is look: client-owned theme tokens, a package render idiom, and three deploy gates"
date: 2026-07-17
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: high
applies_when:
  - Adding motion or animation to a server-driven-UI renderer (entrance stagger, press feedback, tab or accordion swap)
  - Deciding where a look or motion concern lives — the Remote Config wire, the client theme, or block code
  - A rendered SDUI screen looks or behaves wrong and the fix could be code, wire, or a CDN asset
  - Verifying that an SDUI change actually reached the device (rebuild vs Remote Config republish vs CDN upload)
  - Adding a new client-tunable look value and keeping golden tests stable
  - Honoring reduce-motion accessibility for entrance and swap animation at the view level
tags:
  - server-driven-ui
  - motion
  - animation
  - theming
  - client-owned-look
  - remote-config
  - deploy-gates
  - neumorphic
  - golden-tests
---

# Motion is look: client-owned theme tokens, a package render idiom, and three deploy gates

## Context

neo_sdui renders one JSON "wire" into a native Flutter screen. Its founding
constraint is **no look on the wire**: the wire names roles and structure
(`emphasis:"high"`, `tone:"accent"`, block types, order) and carries *zero*
pixels — no hex, no px, no font family, no gradient stops, no shadow, no
spacing. Every pixel lives either in the client-owned `NeoSduiTheme` (the
HostConfig analog) or as a fixed *render idiom* baked into a block. That split
is what lets two guides look completely different while sharing one wire and one
renderer: each `NeoSduiView` is handed its own theme.

This work had to add **motion** — entrance stagger, press feedback, tab
cross-fade — on top of ~15 rounds of screen-by-screen Figma-parity corrections.
Motion is the first thing a naive implementation smuggles onto the wire ("this
card fades in over 300ms"). The question was where each half of motion belongs,
and the answer turned out to be *almost* parallel to look — with one honest
caveat about *why motion is allowed in the package at all* (below). A second,
orthogonal lesson surfaced repeatedly while verifying the work: a change to an
SDUI system reaches the device through one of **three different deploy gates**,
and confusing them burned verification loops chasing a fix that was never going
to appear.

**Dead-ends that shaped this (session history).** The build was not clean —
several wrong turns are the reason the final shapes look the way they do:

- **Fade+rise entrance broke hit-testing.** An `Opacity` fade wrapped around a
  translated (risen) child dropped taps into dead space. Several wrong theories
  were chased (a `paintsChild == false` "poisoning" the transform was
  disproven) before the real cause landed: `RenderTransform.hitTest`
  deliberately skips its own bounds check while `Opacity` hit-tests through the
  plain `RenderBox` path and rejects anything outside its unshifted box. Fix:
  `Transform` **outside**, `Opacity` **inside** — now load-bearing and commented
  in `_motion.dart`.
- **A sticky tab strip built as a `Stack` + a zero-opacity ghost** duplicated
  the tab labels, so `find.text('Desktop')` matched twice and `tester.tap` broke.
  Papering over the test was rejected; the ghost was replaced with a
  single-instance opaque strip.
- **The strip was modeled three times as a translate-hack `_StickyStrip`** before
  accepting that a mid-list `tabs` block cannot be pinned by a style tweak — it
  needs a real `SliverPersistentHeader` (which forces known `minExtent`/`maxExtent`).
- **Blank assets were wrongly blamed on the `neo_sdui_media` add-on** (it only
  adds caching). The real cause was a CDN URL base missing the `neo/`
  app-namespace segment → 403s. The plain-`Image.network` how_to page was the
  proof.
- **Repeated "still broken on device" reports were stale state, not code** — the
  deploy-gate confusion documented below.

## Guidance

### Motion values split the same way look does: values are theme, idiom is code

Look already had two homes. Look **values** (gradient stops, card shadow,
divider color) are theme roles; look **idioms** (the neumorphic emboss geometry,
the ShaderMask gradient-text recipe) are baked into block code. Motion **values**
take the identical split:

- **Motion values → theme tokens.** Four tiers plus a kill switch live on
  `NeoSduiTheme`, client-tunable and per-guide via `copyWith`:

  ```dart
  // packages/neo_sdui/lib/src/theme/neo_sdui_theme.dart
  // Motion is client-owned: bounded animations only, killable per app (KTD9).

  /// Press feedback and cross-fades — the shortest tier.
  final Duration motionDuration;   // default 200ms
  final Curve motionCurve;         // default Curves.easeOutCubic

  /// A swap in place: the selected tab's content, an accordion opening.
  final Duration swapDuration;     // default 340ms

  /// A block's arrival on a freshly built view — the longest tier, and the
  /// only one that staggers.
  final Duration entranceDuration; // default 500ms
  final Curve entranceCurve;       // default Cubic(0.16, 1, 0.3, 1)

  final bool reduceMotion;         // default false
  ```

- **Motion idiom → package renderer.** *Which* widget animates and *how* is a
  fixed rendering concern, all of it in `packages/neo_sdui/lib/src/blocks/_motion.dart`.
  The wire never says "animate"; the block decides, reading only theme values:

  - `entrance()` — staggered rise+fade for top-level blocks. The key move is
    **one `AnimationController` per block driven through an `Interval`**, so a
    whole view's stagger costs no extra timers and can never drift:

    ```dart
    // _EntranceState.initState — one controller over the full window,
    // each block takes its slice via an Interval.
    final enter = widget.theme.entranceDuration.inMilliseconds;
    final delay = _delays[widget.index];
    final total = _delays.last + enter;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay / total,
        (delay + enter) / total,
        curve: widget.theme.entranceCurve,
      ),
    );
    _controller.forward();
    ```

  - `PressScale` — the press-toward-finger `AnimatedScale` every tappable
    shares (a card dips further than a row via `scale`), reading
    `theme.motionDuration` / `theme.motionCurve`.

  - `SwapFade` — the tab-content cross-fade on selection change.

  Two subtleties are load-bearing and commented in place: **Transform must sit
  *outside* Opacity, never inside** (the hit-testing dead-end above):

  ```dart
  // _Entrance.build — Transform outside Opacity so a mid-rise tap still lands.
  return Transform.translate(
    offset: Offset(0, _rise * (1 - t)),
    child: Opacity(opacity: t, child: child),
  );
  ```

  And `SwapFade` gives the *outgoing* child a **zero reverse duration** — two
  blocks cross-fading in place smear; a clean cut to the incoming rise reads as
  a swap:

  ```dart
  return AnimatedSwitcher(
    duration: theme.swapDuration,
    reverseDuration: Duration.zero,
    switchInCurve: theme.entranceCurve,
    // ...
  ```

The wire stays clean: grepping the MCP wire (`deliverables/mcp/mcp.json`) and the
`example/` guides for `duration|curve|motion|animate|"ms"` returns **nothing**.
Motion values never ride the wire, exactly like look values.

### Why motion lives in the package at all — a deliberate keep, not a design mandate (session history)

Motion is *not* governed by the same hard ban as look-on-wire, and the doc would
be dishonest to imply it is. Mid-project the user challenged directly: *"there
are some transitions being written in this package. this shouldn't be the case.
do you agree?"* The honest answer was **yes, partly**: the `entrance()` stagger
is choreography the Figma design does not have (its own source comment admits it
is "a wave the design doesn't have"), and an early sticky-strip translate-hack
was likewise invented. The user then chose to **keep all motion anyway** — on one
condition that makes the keep defensible:

> Motion stays in the package **because it is theme-gated and killable** — every
> animation reads a theme duration/curve and collapses to nothing under
> `reduceMotion` or the OS "disable animations" switch. Un-figma'd choreography
> is allowed *when it is opt-out by construction*; look pixels on the wire are
> never allowed, because they are not.

So the rule is asymmetric, and worth stating precisely: **look values are
banned from the wire; motion values are banned from the wire too, but motion
*choreography* is a permitted package idiom — a judgment call justified by
kill-switch gating, not by the design demanding it.** That is the accurate
version of "motion is look."

### Reduce-motion is folded in once, at the view — an accessibility signal, not a look choice

The platform "disable animations" switch is not per-guide taste, so it lands in
one place — `NeoSduiView._themeFor` — rather than waiting on each client to wire
it up (a client that forgets would animate at a user who asked it not to). It
only ever turns motion **off**, so an app that already set `reduceMotion` keeps
its own kill switch, and an untouched theme is returned by identity so the scope
doesn't needlessly rebuild every block:

```dart
// packages/neo_sdui/lib/src/render/neo_sdui_view.dart
NeoSduiTheme _themeFor(BuildContext context) =>
    widget.theme.reduceMotion || !MediaQuery.disableAnimationsOf(context)
        ? widget.theme
        : widget.theme.copyWith(reduceMotion: true);
```

Consequence: **per-guide motion is free.** Because each `NeoSduiView` already
gets its own theme, tuning a guide's durations, curves, or forcing
`reduceMotion` is a `copyWith` on that theme — no new machinery, same lever look
already used.

### Every SDUI change crosses exactly one of three deploy gates

Before you try to verify a fix, know which gate it crosses — the device only
sees it after *that specific* gate opens. This was the single biggest recurring
friction of the whole effort (session history):

1. **Package or app-theme change → app REBUILD (cold).** Blocks and
   `NeoSduiTheme` are Dart; the app depends on neo_sdui by **local path**
   (`../neo_sdui/packages/neo_sdui`). Hot-reload does **not** reliably apply
   path-package changes — several "still broken" reports were just un-rebuilt
   path packages. A new `_motion.dart`, a new theme role, an emboss tweak — all
   rebuild-gated, and specifically cold-`flutter run`-gated.
2. **Wire change → Firebase Remote Config REPUBLISH.** The wire
   (`deliverables/mcp/mcp.json`) is gitignored and fetched live from the RC key
   `guide_mcp`. The app reads `getString('guide_mcp')` with **no bundled
   default**, so until someone republishes RC the device renders the *old cached
   wire*. Worse, RC itself caches with `minimumFetchInterval: Duration(days: 1)`,
   so even a republished wire can stay invisible on-device for up to a day — a
   debug-mode zero-interval fetch was added to stop the cache masquerading as a
   bug (a fix "working on a different phone" was the tell that it was cache). A
   wire edit is invisible on-device after a mere rebuild.
3. **CDN asset → separate upload** (e.g. `hero.png` to `cdn.neosapien.xyz/neo/…`),
   unrelated to RC and unrelated to the app build. figwire is semantics-only: it
   references image URLs but never uploads bytes; assets are staged under
   `deliverables/mcp/assets/` mirroring the CDN path for the user to upload. The
   sharpest instance of drift here was a URL base missing the `neo/` namespace →
   403s that looked like a rendering bug.

Confusing the gates wastes verification loops. Expecting a wire-gated icon swap
(changing a step's `download`→`export` icon role in the JSON) to appear after
only a rebuild is a category error — that edit is gate #2 and needs the RC push.
And the corollary from the `hero.png` bug: a rendering artifact can live **in
the asset, not the code**. A "stray card border / halo" around the hero turned
out to be a baked ~26px transparent margin plus a soft-shadow halo *in the PNG*;
the fix was cropping the asset (a gate #3 change), not touching the renderer.

### Golden-stability: gate look changes behind null theme roles

Every look value that can vary is a **nullable** theme role that falls back to a
byte-identical flat render when null: `ctaGradient`, `titleGradient`,
`cardGradient`, `backgroundGradient`, `groupGradient`, `accentGradient`,
`grainOverlay`, `divider`, `stepCardColor`. New roles are registered in
`kRoleSlots` (the single source of truth in `theme_compile.dart`), mirroring the
existing `accentGradient`/`divider` pattern. The golden tests deliberately set
**no** gradient roles, so featured/gradient looks fall back to flat and stay
byte-identical run to run. The result: a theme-gated look change doesn't churn
goldens. Only layout-affecting changes regenerate them — this work regenerated
exactly three (`mcp_client_claude`, `mcp_faq`, `mcp_troubleshooting`). Goldens
render in the default test font (Ahem — glyph boxes with color preserved), so
type changes don't churn them either.

## Why This Matters

**One mechanism, not per-feature machinery.** Motion values reusing look's exact
value/idiom split meant there was no new subsystem to learn, test, or theme.
Per-guide motion, the reduce-motion switch, and the kill switch all fell out of
`copyWith` and one `_themeFor` line — the same lever that already produced
per-guide look. Had motion values leaked onto the wire, every guide would need
its own animated payload, every A/B of a duration would be an RC republish, and
accessibility would depend on each client remembering to honor the OS switch.

**The asymmetry keeps the pattern honest.** Distinguishing "motion values are
banned from the wire (like look)" from "motion *choreography* is a permitted
package idiom because it is kill-switch-gated" stops the pattern from being used
to justify smuggling design onto the wire *or* to ban legitimate opt-out-by-
construction animation. The kill switch is the whole license.

**Knowing the gate is the difference between verifying and flailing.** Most
wasted debugging on a server-driven system is verifying against the wrong gate —
rebuilding to check a wire edit, hot-reloading a path package that needs a cold
build, or editing the renderer to fix an artifact baked into a CDN asset. Naming
the three gates up front turns "why didn't my fix show up?" into "which gate does
this cross, and did I open it?"

**Golden stability keeps the safety net trustworthy.** If every theme-gated look
change churned goldens, the golden diff would be noise and reviewers would rubber-
stamp it. Nullable roles that fall back flat mean a golden diff *means something*
— only true layout changes appear.

## When to Apply

- **Any time you add motion (or any look concern) to an SDUI renderer.** Ask: is
  this a *value* (tunable, belongs on the theme) or an *idiom* (which widget
  animates and how, belongs in block code)? Never the wire. And if it is
  choreography the design does not strictly mandate, keep it only if it is
  theme-gated and dies under `reduceMotion`.
- **When a rendered screen looks or behaves wrong** and you're deciding where the
  fix goes — theme role, block idiom, wire, or asset. A stray border/halo is as
  likely to be in the PNG as in the paint code.
- **Before claiming any SDUI change is verified.** Identify the gate (cold
  rebuild / RC republish / CDN upload) and confirm *that* gate opened, not a
  different one — and remember RC's own day-long cache.
- **When adding a new client-tunable look value.** Make it a nullable theme role
  registered in `kRoleSlots` with a byte-identical flat fallback, so goldens stay
  stable and the change is opt-in per guide.
- **For accessibility signals** (reduce-motion and similar): fold them in once at
  the view boundary, additively (only ever turning the effect off), so no client
  can forget them and an app that already opted out is left untouched.

## Examples

### Before → after: a "custom" animated Contact button

A Figma "custom" featured button with an embossed press look and a fade-in
**does not** become a new animated widget or a wire field describing its
animation. It dissolves into the existing split:

- **Look idiom** — the emboss geometry is baked as a `const` inset recipe (a
  rendering constant, like the gradient-text srcIn); the *fill* is the theme's
  `ctaGradient`:

  ```dart
  // packages/neo_sdui/lib/src/blocks/cta.dart
  const List<Inset> _ctaEmboss = [
    Inset(Color(0x33CECECE), Offset(6, 6), 10),   // inset  6  6 10 rgba(206,206,206,.2)
    Inset(Color(0x33000000), Offset(-6, -6), 20), // inset -6 -6 20 rgba(0,0,0,.2)
  ];

  final featured = emphasis == 'high' && theme.ctaGradient != null;
  final Widget box = featured
      ? neumorphic(radius: theme.radiusSm, gradient: theme.ctaGradient,
                   insets: _ctaEmboss, child: content)
      : DecoratedBox(/* flat fill from theme.fill(emphasis) */);
  ```

- **Look value** — `ctaGradient` is nullable; a theme that sets no gradient
  renders the button flat, byte-identical, golden-stable.
- **Motion idiom** — the press feedback is just `PressScale` wrapping it, the
  same one every tappable shares; it reads `motionDuration`/`motionCurve` from
  the theme.

Net wire change: the button carries `emphasis:"high"` and an `action`. No hex,
no emboss, no duration, no curve.

### The neumorphic primitive, reused across blocks

Flutter's `BoxShadow` only casts *outward*, so the inner-shadow look every
neumorphic control needs is a foreground `CustomPaint` clipped to the rounded
box. It was lifted from the neo app's `FigmaLinearGradientButton` inset bevels
into one primitive (`blocks/_neumorphic.dart`, extracted from `tabs.dart` once
the Copy button needed the same idiom) and then reused everywhere:

```dart
// packages/neo_sdui/lib/src/blocks/_neumorphic.dart
const Color kInsetDark = Color(0x42000000); // black at ~26% — the dark half

class Inset {
  const Inset(this.color, this.offset, this.blur);
  // positive offset shades top-left (light); negative shades bottom-right
  // (dark) — CSS `inset <dx> <dy>` semantics.
}

Widget neumorphic({
  required BorderRadius radius, Color? color, Gradient? gradient,
  Border? border, required List<Inset> insets, required Widget child,
}) => DecoratedBox(
      decoration: BoxDecoration(color: color, gradient: gradient,
          borderRadius: radius, border: border),
      child: CustomPaint(
        foregroundPainter: InsetShadowPainter(radius, insets),
        child: child,
      ),
    );
```

Reuse sites — all colors are theme roles, only the inset *geometry* is baked:

- **tabs** (`tabs.dart`): a recessed `tabTrack` groove holding a darker pressed
  pill —

  ```dart
  final trackInsets = <Inset>[
    Inset(kInsetDark, const Offset(3.5, 3.5), 12),
    Inset(theme.onSurface.withValues(alpha: 0.10), const Offset(-1.5, -1.5), 8),
  ];
  return neumorphic(radius: theme.radiusMd, color: theme.tabTrack,
      insets: trackInsets, child: /* the pill row */);
  ```

  where the groove color is a *derived* theme getter, so a re-skin moves it with
  `surface`:

  ```dart
  // neo_sdui_theme.dart
  Color get tabTrack =>
      Color.alphaBlend(onSurface.withValues(alpha: 0.13), surface);
  ```

- **steps** (`steps.dart`): the `_copyButton` on the hero command card — same
  inset-shadow idiom, fill graduated from `tabTrack`→`surface`, hairline from
  the `stepCardBorderColor` role.

### The pinned tab strip: motion + neumorphic + theme, no wire pixels

The Web/Desktop toggle is a pinned `SliverPersistentHeader` whose "floating"
look comes from a **transparent background** (the guide's backdrop shows
through), not a narrowed pill — full content-width, selection owned by
`NeoSduiView` so the pinned strip and the scrolling content share it. Getting
here took three wrong models (a mid-list `tabs` block cannot be pinned by a
translate hack — it needs a real sliver with known extents), and the final
shape is a `NeoSduiView` StatefulWidget dual-path build: a byte-identical
`ListView` for non-tabs docs (zero golden churn) and a `CustomScrollView` with a
pinned header only when a top-level `tabs` block exists, sharing selection via a
`ValueNotifier`. The strip is the neumorphic segmented control; swapping tabs
cross-fades the content via `SwapFade`. Everything visible is a theme role or a
baked idiom; the wire names only the `tabs` block and its labels.

### A wire edit that a rebuild can't show

Changing a setup step's icon role in `mcp.json` from `download` to `export`
(both resolve through `theme.icons` to real glyphs) is a **gate #2** change. It
is correct in the repo the moment the JSON is saved, and still invisible on any
device until RC key `guide_mcp` is republished — because the app reads
`getString('guide_mcp')` with no bundled default and renders the last cached
wire (and even then, up to RC's day-long `minimumFetchInterval` behind). Rebuilding
the app proves nothing here; only the RC push does.

## Related

- `sdui-look-is-client-owned.md` — the parent principle (the wire carries
  semantics, the client owns the look). This doc is the concrete build-out of
  that doc's abstract "Motion and transitions are the same client-owned concern"
  section, plus the two pieces it does not cover: the three-deploy-gate taxonomy
  and the `_neumorphic.dart` primitive.
- `accent-text-gradient-theme-owned.md` — the same nullable-theme-role + flat
  fallback + golden-stability mechanism this doc reuses for every gradient role.
- `vary-block-by-render-context-not-wire-flags.md` — the render-context idiom
  (box vs pinned tab forms; nested-header scale) and the Remote Config
  stale-cache reality that is the runtime consequence of deploy gate #2.
- `addon-core-floor-and-last-wins-upgrade.md` — a genuinely new capability rides
  a client release; that release cost is deploy gate #1 (package → rebuild).
- (auto memory [claude]) *custom-widget-three-homes* — before wiring a "custom"
  Figma element, classify look→theme / composition→wire / new-kind→registry;
  most "custom" elements dissolve into theme, as the Contact button did here.
- (auto memory [claude]) *per-guide-look-via-client-theme* — guides differ by
  each `NeoSduiView` getting its own `NeoSduiTheme`, not per-guide widgets or
  wire pixels; this is exactly why per-guide motion is free.
- (auto memory [claude]) *look-is-data-not-pixels* — prefer asserting the
  compiled theme's values over pixel goldens; ~9% of defects are irreducible
  taste a golden won't catch anyway.
