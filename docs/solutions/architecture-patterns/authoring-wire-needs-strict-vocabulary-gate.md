---
title: Authoring resilient-runtime SDUI needs a strict vocabulary gate the runtime deliberately omits
date: 2026-07-14
last_updated: 2026-07-15
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: medium
applies_when:
  - generating or hand-authoring neo_sdui wire JSON
  - adding a new wire authoring or generation tool (e.g. the figwire skill)
  - deciding whether the runtime validateDocument can serve as a write gate
  - reviewing why a block vanished or collapsed in a rendered document
related_components:
  - documentation
  - testing_framework
tags: [neo-sdui, server-driven-ui, wire, validation, figwire, code-generation, block-vocabulary]
---

# Authoring resilient-runtime SDUI needs a strict vocabulary gate the runtime deliberately omits

## Context

`figwire` is a skill that turns any Figma selection (page, frame, component, node
link, node id, or a pasted screenshot) into **neo_sdui-compliant wire JSON**
(`{version, blocks, views}`) bound for Firebase Remote Config. It is the inverse
of `neofig` (Figma → Flutter widget code): `neofig` writes the *look*, `figwire`
writes the *semantics*.

What makes generation tractable at all is the premise documented in
[`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md): the wire is
**semantics-only** — a fixed 14-type block vocabulary (`header`, `text`, `cta`,
`callout`, `media`, `code`, `card`, `steps`, `faq`, `tabs`, `row`, `column`,
`group`, `spacer`) with no hex, px, font, gradient, or spacing on it. That
reduces "generate a UI" to a **14-symbol classification problem**: for each Figma
node, pick the one block type it maps to and fill its content.

But that premise collides head-on with the runtime's deliberate resilience
(documented in
[`resilient-block-rendering-guarded-typed-reads.md`](resilient-block-rendering-guarded-typed-reads.md)).
The renderer is built to never crash on bad wire — which means it is built to
*swallow* exactly the mistakes a classifier makes. The generator's need at
authoring time is the mirror image of the runtime's need at render time.

## Guidance

**The lesson: authoring/generation of resilient-runtime SDUI needs a STRICT
vocabulary gate that the runtime deliberately omits.** The permissive validator
the runtime ships cannot be reused as a write gate — that is a category error.

Three facts combine into the hazard:

1. **The renderer silently drops an off-roster `type` to `SizedBox.shrink`.** An
   unknown type string has no builder, so it renders nothing — no error, no log.
2. **Block builders enforce no required fields.** Every field is read through a
   guarded typed default (`stringOr` / `intOr` / `nodeList` …), so a *valid* type
   missing its content degrades to empty/collapsed rather than complaining.
3. **`validateDocument` is structural-only.** In
   `packages/neo_sdui/lib/src/model/validation.dart` it checks only that `type`
   is a non-empty string, flags reserved field names, and recurses `fallback`. It
   does NOT enforce the 14-type roster and does NOT enforce any per-block required
   field — so it passes both failures above.

So a mis-classified block sails through `validateDocument` and then *vanishes*
from the rendered UI. You cannot use the runtime's validator as the authoring
gate.

The resolution is `validateWireVocabulary` in
`packages/neo_sdui/lib/src/model/validate_vocabulary.dart` — a strict gate layered
*on top of* `validateDocument`, with two severities:

```dart
enum WireIssueSeverity {
  /// Off-roster `type`: the renderer drops the block, so it would vanish from
  /// the output. Hard — a caller should refuse to write.
  block,

  /// Missing required content: the renderer degrades the block to
  /// empty/collapsed, which a human sees in the preview and report. Advisory.
  warn,
}
```

- **Off-roster `type` (or a non-map block) → `block` (HARD).** The write must be
  refused, because the element would silently disappear. The allowlist is
  core-only:

  ```dart
  const Set<String> kCoreBlockTypes = {
    'header', 'text', 'cta', 'callout', 'media', 'code', 'card',
    'steps', 'faq', 'tabs', 'row', 'column', 'group', 'spacer', //
  };
  ```

  A core-only set is correct even for add-on-composed engines, because add-ons
  re-register *existing* types (last-wins) rather than introducing new `type`
  strings. The off-roster branch:

  ```dart
  final type = block['type'];
  if (type is! String || !kCoreBlockTypes.contains(type)) {
    final shown = type is String ? type : '';
    out.add(WireVocabIssue(
      '$path.type',
      "'$shown' is not one of the ${kCoreBlockTypes.length} core block types",
      WireIssueSeverity.block,
    ));
    _checkFallback(block, path, out); // a valid fallback can still carry issues
    return;
  }
  ```

- **Missing required content → `warn` (advisory).** The block degrades to
  empty/collapsed, which a human catches in the preview PNG, so it need not block
  the write. The required-field table had to be **authored, not derived** — the
  builders enforce nothing, so there was no existing contract to read off. It
  lives in the `_missingRequired` switch (`header` needs `title`, `code` needs
  `content`, `row`/`column`/`group` need non-empty `children`, etc.).

- **Recurse only the real `BlockNode` carriers the renderer traverses:**
  top-level `blocks`, each view's `blocks`, `children` (row/column/group), each
  `tabs[].blocks`, a `steps` item's optional `blocks` list, and every block's
  `fallback`. **The trap:** a `steps`/`faq` item MAP is leaf content — a stray
  `type` on the item *itself* must be ignored, not flagged — but a `steps` item's
  `blocks` sub-list *is* a real carrier the renderer builds, so it is recursed
  (added when a step gained composed content — see the three-homes decision in
  [`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md)). The rule
  generalizes: **any new place that holds child blocks must join this recursion
  set, or an off-roster type inside it drops silently** — a plain new *field*
  never does, only a new carrier.

- **Never throws; collects issues** (same posture as `validateDocument`).

Around the validator sits a **4-gate classify-then-verify pipeline** run before
any write:

1. **Strict validate** — `validateDocument` + `validateWireVocabulary`;
   `blocking = all structural + vocab.isBlocking` must be empty or the skill
   refuses to write (`packages/neo_sdui/test/tools/check_wire_test.dart`).
2. **Coverage report** — generated blocks compared against an *independent* Figma
   inventory from `get_metadata`; softened when only a screenshot is available
   (you cannot enumerate nodes from a picture).
3. **Structural preview PNG** — render the wire to a PNG for eyeballing block
   presence, type, order, and nesting
   (`packages/neo_sdui/test/tools/render_wire_test.dart`). Structural only:
   runtime fonts render as the default test font and network images as their
   error placeholder — enough for structure, not pixel/font fidelity.
4. **Secret-scan** — scan extracted Figma text for API keys / tokens / internal
   URLs before writing (and before any future Firebase push). The Figma REST token
   is supplied only via env var, gitignored, never hardcoded or logged.

## Why This Matters

The failure mode without the gate is the worst kind of bug: **silent, no stack
trace, only caught by eyeballing.** A mis-classified block (`{"type":"banner"}`)
or an under-filled block passes `validateDocument`, then the renderer drops or
collapses it — the element simply *vanishes* from the rendered UI with zero errors
anywhere. There is nothing to grep for, no exception to catch, no failing test
unless someone happens to compare the render against the source pixel by pixel.

The general principle: **any system that is resilient-by-design at runtime inverts
its needs at authoring time.** Resilience means the runtime tolerates malformed
input by degrading quietly — precisely the behavior that, at generation time, hides
a generator's mistakes. Reusing the runtime's permissive validator as an authoring
gate is a category error: the runtime's validator is built to *let things through*,
the authoring gate must be built to *stop them*.

This ties directly to why generation is tractable in the first place. Because the
look is client-owned and the wire is semantics-only, generation collapses to a
14-symbol classification problem. But the same property — a small fixed vocabulary
that the runtime treats permissively — is exactly why the classification must be
gated: an off-by-one in classification does not error, it disappears.

## When to Apply

- Generating or hand-authoring neo_sdui wire JSON.
- Adding any wire-authoring tool or skill (a second generator, a migration
  script, a hand-edit linter).
- Debugging why a block **silently disappeared** from a rendered document — start
  by running `validateWireVocabulary`; an off-roster `type` or a missing required
  field is the usual cause.
- Designing a validator for *any* resilient-by-default renderer — build a separate
  strict authoring gate rather than reusing the runtime's tolerant one, and split
  its findings into hard (would-vanish) vs. advisory (would-degrade-visibly).

## Examples

**Off-roster type — `validateDocument` accepts, `validateWireVocabulary`
blocks.** A generator that mis-classifies a section as `banner`:

```dart
validateWireVocabulary({
  'version': 1,
  'blocks': [
    {'type': 'banner', 'title': 'x'},
  ],
});
// → one issue, isBlocking == true, path == 'blocks[0].type'
```

`validateDocument` passes this (`banner` is a non-empty string), and the renderer
would drop it to `SizedBox.shrink`. Only the vocabulary gate catches it — as a
`block` severity, so the skill refuses to write.

**An item MAP is leaf content, not a block.** A stray `type` on a `steps`/`faq`
item must be ignored, never recursed (a `steps` item's `blocks` *sub-list* is a
separate carrier that IS recursed — see the carriers bullet above):

```dart
validateWireVocabulary({
  'version': 1,
  'blocks': [
    {
      'type': 'faq',
      'items': [
        {'question': 'q', 'answer': 'a', 'type': 'banner'},
      ],
    },
  ],
});
// → no issues; the item's `type` is content, not a nested block
```

If `_checkBlock` recursed `items`, this would falsely hard-block on the item's
`banner`. It does not — `items` is read only for its required-field content.

**Env-gated skill-entrypoint test — a callable gate that keeps `flutter test`
green.** The two tool tests live in the package's own `test/` tree but gate on an
env var, so plain `flutter test` skips them (the suite's 2 expected skips) and the
skill runs them by setting `NEO_WIRE_JSON`. From `check_wire_test.dart`:

```dart
void main() {
  final wirePath = Platform.environment['NEO_WIRE_JSON'];

  test('wire JSON is structurally sound and on-vocabulary', () {
    final map =
        jsonDecode(File(wirePath!).readAsStringSync()) as Map<String, Object?>;

    final structural = validateDocument(map);
    final vocab = validateWireVocabulary(map);
    // ... print every issue ...
    final blocking = <String>[
      ...structural.map((i) => i.toString()),
      ...vocab.where((i) => i.isBlocking).map((i) => i.toString()),
    ];
    expect(blocking, isEmpty,
        reason: 'Blocking issues — do not write this document:\n'
            '${blocking.join('\n')}');
  }, skip: wirePath == null);
}
```

The `skip: wirePath == null` on a `Platform.environment` read is the reusable
pattern for shipping a callable "skill entrypoint" inside a package test suite —
no separate binary, and CI stays green.

## Related

- [`resilient-block-rendering-guarded-typed-reads.md`](resilient-block-rendering-guarded-typed-reads.md)
  — the runtime counterpart. That doc makes the renderer resilient (a bad block
  degrades to fallback or `SizedBox.shrink`, never crashes); this doc treats that
  same silent degrade as a write-time hazard and takes the opposite posture.
- [`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md) — the premise
  source: the semantics-only, client-owned wire and the 14-type vocabulary that
  `validateWireVocabulary` enforces at authoring time.
- [`addon-core-floor-and-last-wins-upgrade.md`](addon-core-floor-and-last-wins-upgrade.md)
  — why `kCoreBlockTypes` can stay core-only: add-ons re-register existing types
  (last-wins) instead of minting new `type` strings, so the 14-type gate never
  needs to grow per add-on.
```