---
title: Every wire value reaching a widget must pass through guarded typed reads
date: 2026-07-13
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: medium
applies_when:
  - rendering remote or untrusted wire JSON into Flutter widgets in a server-driven UI
  - relying on a per-block try/catch to keep one bad block from crashing the whole view
  - a wire value flows into a widget constructor or a layout constraint (size, count, aspect ratio)
  - reading a wire field with a raw cast or a null-only fallback instead of a type-checked read
  - an add-on or new block re-implements a read rather than calling the core guarded read
tags:
  - server-driven-ui
  - resilience
  - error-handling
  - flutter
  - block-registry
  - typed-reads
  - render-object
  - degrade-gracefully
---

# Every wire value reaching a widget must pass through guarded typed reads

## Context

neo_sdui renders one Firebase Remote Config "wire" JSON document into themed Flutter widgets. Its central invariant (CONCEPTS.md, the engine plan): rendering is resilient. An unknown, unsatisfiable, or throwing block degrades to its authored `fallback` or is skipped — it never crashes the view. **Blast radius is one block.** The renderer enforces this with a per-block try/catch in `NeoSduiView._buildOne`:

```dart
return Builder(builder: (ctx) {
  try {
    return _registry.builderFor(node.type)!(ctx, node);
  } catch (_) {
    final fb = node.fallback == null ? null : _buildOne(node.fallback!);
    return fb ?? const SizedBox.shrink();
  }
});
```

There is a trap in this guard, and it is not obvious. **The try/catch only catches exceptions thrown synchronously, during `build()`.** Many Flutter widgets do not validate their inputs in `build()` — they validate in the *render object*, with an `assert` that fires at **mount / layout time**, after the builder has already returned and the try/catch has unwound. Those asserts sail straight past the guard and surface as a red `ErrorWidget`, breaking the "never crashes the view" promise.

Concrete cases:

- `AspectRatio` asserts `aspectRatio > 0 && aspectRatio.isFinite` — fires at mount. A wire `"ratio": 1e400` decodes to `double.infinity` and trips `isFinite`.
- `SizedBox` / `RenderConstrainedBox` asserts `height >= 0` — fires at mount. A negative computed height trips it.
- A raw `item['x'] as String?` cast runs at build **only if it is in the block's own `build()`**. But in a deferred `StatefulWidget.build` (the faq accordion opens on tap), it runs at element mount — again outside `_buildOne`'s try/catch.

And note the debug-vs-release split: asserts only run in debug and profile. In release they are stripped, so the same bad wire does not red-box — it *silently mis-renders* (an infinite-ratio box, a zero-height gap, a dropped string). Either way the authored `fallback` never gets its chance.

## Guidance

Every wire value that reaches a widget or a layout constraint must pass through the package's guarded read layer. Do not let a raw field touch a constructor.

**Route reads through the typed accessors on `BlockNode`.** They check the runtime type and return your default on a mismatch instead of throwing:

```dart
String? stringOr(String key, [String? or]) =>
    fields[key] is String ? fields[key] as String : or;
int? intOr(String key, [int? or]) =>
    fields[key] is int ? fields[key] as int : or;
bool boolOr(String key, {bool or = false}) =>
    fields[key] is bool ? fields[key] as bool : or;
```

**Use `ratioOr` for anything feeding an aspect ratio.** It is the canonical example of guarding a mount-time assert — its own doc comment says so:

```dart
/// Guards non-positive AND non-finite values: AspectRatio asserts both `> 0`
/// and `isFinite`, and its isFinite assert fires at render-object mount —
/// outside the per-block try/catch — so an unguarded Infinity ("ratio": 1e400
/// decodes to double.infinity) would surface as an ErrorWidget instead of
/// degrading. (NaN > 0 is already false, so NaN is rejected.)
double ratioOr(double or) {
  final r = fields['ratio'];
  if (r is num && r > 0 && r.isFinite) return r.toDouble();
  final w = intOr('width'), h = intOr('height');
  if (w != null && w > 0 && h != null && h > 0) return w / h;
  return or;
}
```

**Clamp any number that becomes a constraint.** A typed read still returns the author's number; if that number feeds a width/height/flex, bound it so it can never be negative (assert) or absurd (frozen layout): `node.intOr('size', 1)!.clamp(0, 100)`.

**Never bare-`as`-cast a raw map field.** `mapList` items (`steps.items`, `faq.items`) are plain `Map<String, Object?>` with no `BlockNode` accessors. `item['answer'] as String? ?? ''` guards *null* but not *wrong type* — an unquoted number fails the cast. Read through a local type-guard helper, or inside a try/catch:

```dart
String _str(Object? v) => v is String ? v : '';
```

**In an add-on, call the core guarded read — do not re-implement it.** A private re-implementation of a core read silently drops whatever guard the core one carries. If you override a core block, reach through to `node.ratioOr(...)`, `node.stringOr(...)`, etc.

The mechanism to keep in mind at every one of these points: *the input validation you are relying on may not run during `build()`; it may run at mount, past the guard.* That is why the defense has to be at the read, not at the catch.

## Why This Matters

The whole value proposition of a server-driven UI is that a content author can push a wire change without shipping an app. That only holds if a plausible authoring slip damages at most the one block it appears in. The slips here are not exotic — they are the ones a human makes in JSON: an unquoted number (`"answer": 10` instead of `"10"`), a string where a list was expected (`"bullets": "hi"`), objects where strings were expected, a hand-typed `"ratio": 1e400`, a required version written `"v2"`.

Without the guarded read, each of those escalates from "one block quietly degrades" to one of two failures, depending on build mode:

- **Debug / profile:** the mount-time assert fires and red-boxes the entire guide — every sibling block gone, replaced by a stack trace. The blast radius is the whole screen, not one block.
- **Release:** the assert is stripped, so nothing red-boxes — but the block mis-renders silently (infinite-height media, a zero gap, a dropped bullet) and the authored `fallback` is skipped. The failure is invisible until a user reports a broken screen.

Both defeat the invariant. The guarded read collapses both back to the intended behavior: the bad block degrades to its fallback or a `SizedBox.shrink()`, and everything around it renders.

## When to Apply

- Writing or reviewing **any block builder** — before a wire value reaches a widget constructor.
- Reading **any wire field** — reach for `stringOr` / `intOr` / `boolOr` / `ratioOr`, not `fields[...]` plus a cast.
- **Any value flowing into `AspectRatio`, `SizedBox`, flex, or any constraint** — confirm it is typed *and* bounded (finite, non-negative, capped).
- Reading a **raw `mapList` item** (`steps.items`, `faq.items`) — these have no `BlockNode` accessors, so guard the type locally; never `as`-cast.
- Writing an **add-on that overrides a core block** — call the core guarded read; a re-implementation loses the guard.
- Reviewing a **capability/`requires` gate** — check it fails *closed*: an unparseable requirement must mean "unmet → fallback", never "satisfied".

## Examples

**faq — raw-map field, cast at deferred mount.** The `?? ''` only guarded null; a numeric `answer` failed the `as String` cast when the accordion opened (a `StatefulWidget.build` at element mount, outside `_buildOne`'s try/catch) and red-boxed the row.

```dart
// before
Text(item['question'] as String? ?? '')
Text(item['answer']   as String? ?? '')

// after — type-guard, matching every other block's safe read
String _str(Object? v) => v is String ? v : '';
Text(_str(item['question']))
Text(_str(item['answer']))
```

**spacer — number into a constraint.** `size: -1` built a negative `SizedBox` height whose `RenderConstrainedBox` assert fires at mount.

```dart
// before
SizedBox(height: theme.blockSpacing * node.intOr('size', 1)!)

// after — clamp: floor kills the negative-constraint assert, cap kills a monstrous gap
final size = node.intOr('size', 1)!.clamp(0, 100);
SizedBox(height: theme.blockSpacing * size);
```

**callout — `as List` cast plus silent drop.** `(node.fields['bullets'] as List?)?.whereType<String>()` threw on a bare-string `bullets`, and a title-less callout with no usable bullets painted a stray empty tinted square.

```dart
// after
final rawBullets = node.fields['bullets'];
final bullets = rawBullets is List
    ? rawBullets.whereType<String>().toList()
    : const <String>[];
if (title == null && bullets.isEmpty) return const SizedBox.shrink();
```

**requires gate — fail open → fail closed.** A non-numeric required version parsed to `0`, so any present capability satisfied it: the engine rendered an unsupported block and skipped the authored fallback.

```dart
// before — "v2".split('.').first is "v2"; int.tryParse -> null -> ?? 0 -> always satisfied
final need = int.tryParse(e.value.split('.').first) ?? 0;
if (have < need) return false;

// after — unparseable means "can't satisfy" -> unmet -> fallback
final need = int.tryParse(e.value.split('.').first);
if (need == null || have < need) return false;
```

**media add-on — re-implemented read lost the guard.** The add-on carried a private `_ratioOf` that dropped core `ratioOr`'s `isFinite` check, so `"ratio": 1e400` → `double.infinity` → `AspectRatio` isFinite assert at mount. The fix was to *delete* `_ratioOf` and call the core read:

```dart
// after
return CachedVideo(url: url, ratio: node.ratioOr(_videoRatio), ...);
return CachedImage(url: url, ratio: node.ratioOr(_imageRatio));
```

**The degrade-proving test shape.** Every one of these fixes shipped a widget test that pumps the exact bad wire, asserts no exception escaped, and confirms a sibling still renders. For a deferred path, drive the interaction (tap) that triggers the mount-time cast:

```dart
testWidgets('faq with a non-string question/answer degrades, does not crash',
    (tester) async {
  await _pump(tester, {
    'type': 'faq',
    'items': [
      {'question': 2024, 'answer': 'x'},        // numeric question (first-render path)
      {'question': 'How many?', 'answer': 10},  // numeric answer (open path)
    ],
  });
  expect(tester.takeException(), isNull);        // no red ErrorWidget on first render
  await tester.tap(find.text('How many?'));      // opening casts the numeric answer
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
});
```

```dart
testWidgets('spacer with a negative size degrades without crashing',
    (tester) async {
  await _pump(tester, {
    'type': 'column',
    'children': [
      {'type': 'spacer', 'size': -1},
      {'type': 'text', 'body': 'after'},
    ],
  });
  expect(tester.takeException(), isNull);
  expect(find.text('after'), findsOneWidget);    // the sibling still renders
});
```

`tester.takeException()` being null is the assertion that catches a mount-time assert a plain "does it render" test would miss.

## Related

- [`addon-core-floor-and-last-wins-upgrade.md`](addon-core-floor-and-last-wins-upgrade.md) — sibling resilience pattern at a different layer: it degrades via last-wins / core-floor at *registration* time; this doc degrades via guarded reads at *render* time. The media `ratioOr` divergence fixed here was one such last-wins add-on override.
- [`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md) — defines the wire→widget boundary and what the wire may carry; this is its read-safety companion: how every value crossing that boundary must be read.
- [`../developer-experience/testing-video-player-widgets-headlessly.md`](../developer-experience/testing-video-player-widgets-headlessly.md) — same failure family (a throw inside build red-boxes instead of degrading to the placeholder) and it tests the media add-on whose `ratioOr` this doc guarded.

## References

The "assert fires at render-object mount, outside the build-time try/catch"
mechanism is Flutter framework behavior, not a neo_sdui invention:

- **Flutter — `AspectRatio`.** Its render object asserts `aspectRatio > 0 && aspectRatio.isFinite` at layout, after the widget is built — why an infinite wire `ratio` escapes a build-time `try/catch`. <https://api.flutter.dev/flutter/widgets/AspectRatio-class.html>
- **Flutter — `BoxConstraints` (behind `SizedBox`).** Constraint validity (`height >= 0`) is asserted at layout, not construction — the same escape path for a negative `spacer` size. <https://api.flutter.dev/flutter/rendering/BoxConstraints-class.html>
- **Flutter — Remote Flutter Widgets (`rfw`), Limitations.** Reinforces keeping interactivity and robustness-sensitive rendering in Flutter code (here, the guarded reads) rather than trusting arbitrary remote input. <https://pub.dev/packages/rfw>

The SDUI prior art behind the resilience *goal* (degrade, never crash) lives in the sibling docs [`addon-core-floor-and-last-wins-upgrade.md`](addon-core-floor-and-last-wins-upgrade.md) and [`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md), which carry their own References sections.
