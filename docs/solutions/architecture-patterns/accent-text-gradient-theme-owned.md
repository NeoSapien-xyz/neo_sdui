---
title: "Accent text renders as a theme-owned gradient via one shared neoText helper"
date: 2026-07-13
category: architecture-patterns
module: neo_sdui
problem_type: architecture_pattern
component: tooling
severity: medium
applies_when:
  - a role-based color (accent) must become gradient-capable across many blocks without per-element special-casing
  - the visual treatment must stay client-owned in NeoSduiTheme and never leak onto the wire
  - the wire should carry only semantic intent (tone) or string-or-runs, never gradient stops
  - inline styled runs must render inside flowing multi-line text without fragile createShader rect math
  - the flat no-gradient default must stay byte-identical and golden-stable
tags:
  - server-driven-ui
  - gradient-text
  - shadermask
  - theming
  - flutter
  - rich-text
  - client-owned-look
  - widgetspan
---

# Accent text renders as a theme-owned gradient via one shared neoText helper

## Context

neo_sdui renders a Remote Config "wire" JSON document into themed Flutter widgets. The MCP guide's design leans on neon-green accent text everywhere, and much of it is a *gradient*: the step-index numbers, accent headings, and inline brand words ("NeoSapien") sitting inside otherwise-plain sentences. The package had none of this — titles and step numbers were flat-color `Text`, and there was no way to say "part of this string is accent."

Two constraints shaped the fix:

- **KTD9 — gradients are client-owned, never on the wire.** Like all look, gradient stops live on the client. The wire may name intent (*this is accent*) but must never carry a hex or a stop list. Colors already work this way; gradients had to follow.
- **prefer-dynamic-inference (memory).** Derive the look from ONE general mechanism, not a special case per element. The two guides (how_to, mcp) already differ only by the `NeoSduiTheme` handed to each `NeoSduiView` — per-guide *data*, not per-guide widgets or wire pixels. The gradient had to slot into that same seam: how_to sets no gradient (stays flat), mcp sets one (goes green), zero wire or code divergence.

## Guidance

Add gradient-accent support as one theme slot plus one shared helper, routed into every block that renders accent text.

**1. A nullable, client-owned theme slot.** `NeoSduiTheme.accentGradient` is a `Gradient?` that sits beside `cardShadow` — same category (client-owned surface pixels, never on the wire). When null, accent text stays the flat `accent` color, byte-identical to the pre-gradient render, so a theme that leaves it null regenerates no goldens. Two guides differ purely by whether their theme sets it.

**2. One `neoText` helper** that every block calls instead of building `Text` directly. It parses the wire value into runs, then picks one of three render paths:

- **Whole accent line** → ONE `ShaderMask(blendMode: BlendMode.srcIn, ...)` over the `Text`. `srcIn` fills the glyph shapes with the gradient; the child `Text`'s own color is irrelevant — only its coverage matters, so it's painted opaque white (`0xFFFFFFFF`). A single ShaderMask over the whole `Text` wraps across lines naturally.
- **Inline accent run** (a brand word inside a sentence) → a baseline-aligned `WidgetSpan` wrapping a ShaderMask'd `Text`, inside a `Text.rich`. **Why WidgetSpan, not a `foreground: Paint()..shader`:** a shader on a `TextStyle` is created against bounds you'd have to estimate with `createShader(Rect)` — fragile rect math for a run whose position depends on line-wrapping. The WidgetSpan scopes the gradient to that run's *own* laid-out box, so `createShader(bounds)` is exactly right with no measurement. The caveat: an inline gradient run is an atomic box — it won't line-wrap internally. Fine for brand words; a long accent phrase must be split into runs.
- **No gradient (or no accent) / single run** → a plain `Text` fast path, so the common case stays golden-stable.

**3. The wire names ONLY intent.** A block carries `tone: "accent"` for a whole line, or an inline run's tone in a **string-or-runs** field: a text value that is either a plain `String` or a list mixing strings and `{"text": "...", "tone": "accent"}` maps. This mirrors Microsoft Adaptive Cards' `RichTextBlock` inlines — each run carries a semantic color *role*, never a hex. The theme owns the stops.

**4. Guarded parsing.** `_parseRuns` reads runs with `is` type-checks (`e is String`, `e is Map`, `e['text'] is String`), never a raw `as` cast, so a malformed run (`{"text": 42}`) degrades to `''` instead of throwing at mount — consistent with the guarded-reads resilience pattern already in this repo.

**5. Routed into** header (title), text (body), steps (the `$n` number via `accentAll: true`, plus the caption which may now carry inline runs), and tabs (selected label).

## Why This Matters

- **The green look varies per guide with zero wire or code change.** how_to hands in a theme with no gradient → flat accent; mcp hands in a theme with one → gradient. Same blocks, same wire, one differing data field.
- **No gradient stops leak onto the wire.** The stops stay on the client-owned side, exactly like colors and `cardShadow`. The wire's vocabulary grows by one word — `tone: "accent"` — not by a stop list.
- **The mechanism is general, not per-element.** The *accent role itself* is gradient-capable. Step numbers, headings, and inline brand words all flow through the same `neoText` path; nothing is special-cased.
- **Turning it off is free.** Null gradient → the plain-`Text` fast path → byte-identical goldens. Adding the capability cost the flat guides nothing.

## When to Apply

- Rendering any accent or brand text that a block emits — route it through `neoText`, not a bare `Text`.
- Needing *part* of a string in a different treatment — reach for the string-or-runs shape (a list of strings + `{text, tone}` maps) rather than splitting the block.
- Adding a look that must vary per guide but must not touch the wire — put it in `NeoSduiTheme` as a nullable client-owned slot, defaulting to the existing render so flat guides stay golden-stable.
- Any time you're tempted to put a gradient, hex, or other pixel on the wire — stop. The wire names a *role*; the theme owns the pixels.

## Examples

**The `neoText` helper** — parse runs, then pick a path:

```dart
Widget neoText(
  NeoSduiTheme theme,
  Object? value,
  TextStyle style, {
  bool accentAll = false,
}) {
  final runs = _parseRuns(value);
  final grad = theme.accentGradient;
  final accentStyle = style.copyWith(color: theme.accent);

  bool isAccent(_Run r) => accentAll || r.accent;

  // No gradient available (or no accent text) -> flat. A single run collapses to
  // a plain Text so the common case stays golden-stable.
  if (grad == null || !runs.any(isAccent)) {
    if (runs.length <= 1) {
      final r = runs.isEmpty ? const _Run('', false) : runs.first;
      return Text(r.text, style: isAccent(r) ? accentStyle : style);
    }
    return Text.rich(TextSpan(children: [
      for (final r in runs)
        TextSpan(text: r.text, style: isAccent(r) ? accentStyle : style),
    ]));
  }

  // Whole line is accent -> one ShaderMask over the joined text (wraps normally).
  if (runs.every(isAccent)) {
    return _shaded(grad, runs.map((r) => r.text).join(), style);
  }

  // Mixed: only the accent runs get a gradient WidgetSpan; plain runs stay text.
  return Text.rich(TextSpan(children: [
    for (final r in runs)
      if (isAccent(r))
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          // ponytail: an inline gradient run is an atomic box — it won't
          // line-wrap internally. Fine for brand words ("NeoSapien"); split a
          // long accent phrase into separate runs if it must wrap.
          child: _shaded(grad, r.text, style),
        )
      else
        TextSpan(text: r.text, style: style),
  ]));
}
```

**The srcIn-over-white idiom** — the gradient fills the glyphs; the child's color is throwaway:

```dart
Widget _shaded(Gradient gradient, String text, TextStyle style) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: Text(text, style: style.copyWith(color: const Color(0xFFFFFFFF))),
    );
```

**Guarded run parsing** — a bad run degrades, never throws:

```dart
List<_Run> _parseRuns(Object? value) {
  if (value is String) return [_Run(value, false)];
  if (value is List) {
    return [
      for (final e in value)
        if (e is String)
          _Run(e, false)
        else if (e is Map)
          _Run(e['text'] is String ? e['text'] as String : '',
              e['tone'] == 'accent'),
    ];
  }
  return const [];
}
```

**The wire — intent only** (a text block with an inline brand run):

```json
{
  "type": "text",
  "body": [
    "Sign in with your ",
    { "text": "NeoSapien", "tone": "accent" },
    " account"
  ]
}
```

No stops anywhere. The whole-line form is just a scalar plus a tone: `{"type": "header", "title": "NeoSapien", "tone": "accent"}`.

**The theme slot — where the stops actually live** (from the mcp guide's theme):

```dart
// Accent text (step numbers, accent headings, inline brand runs) sweeps neon
// green. Client-owned stops, like cardShadow; the wire only ever names `accent`.
accentGradient: LinearGradient(
  colors: [Color(0xFF2DF790), Color(0xFF00F1A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),
```

The how_to theme simply omits this line → its accent text stays flat, its goldens unchanged.

**A call site** — steps passes the number as a whole-accent line, the caption as string-or-runs:

```dart
return Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    neoText(theme, '$n', index, accentAll: true), // number -> whole-line gradient
    const SizedBox(width: 12),
    Expanded(child: body),                         // caption -> neoText(theme, cap, ...)
  ],
);
```

**The degrade-proving test** — a malformed run mounts clean:

```dart
testWidgets('a malformed run degrades without crashing', (tester) async {
  await _pump(tester, {
    'type': 'text',
    'body': [
      {'text': 42}, // bad run text -> '' (no throw at mount)
      'ok',
    ],
  }, _gradTheme);
  expect(tester.takeException(), isNull);
  expect(find.text('ok'), findsOneWidget);
});
```

And the null-gradient golden-stability guard, proving "off is free":

```dart
testWidgets('an accent heading with no gradient stays flat accent (golden-stable)',
    (tester) async {
  await _pump(tester,
      {'type': 'header', 'title': 'NeoSapien', 'tone': 'accent'}, _plain);
  expect(find.byType(ShaderMask), findsNothing);
  expect(tester.widget<Text>(find.text('NeoSapien')).style!.color, _plain.accent);
});
```

## Related

- [`sdui-look-is-client-owned.md`](sdui-look-is-client-owned.md) — the parent principle. This doc is the concrete instantiation of that one's `tone:"accent"` role: the semantic token resolves to a theme-owned `accentGradient`, the pixels staying off the wire (KTD9).
- [`resilient-block-rendering-guarded-typed-reads.md`](resilient-block-rendering-guarded-typed-reads.md) — read-safety companion. `_parseRuns` reads the string-or-runs value through the guarded typed-read pattern that doc defines, dodging the same mount-time assert trap (defense at the read, not the catch).

## References

- **Microsoft Adaptive Cards — `RichTextBlock` / `TextRun`.** The string-or-runs shape mirrors Adaptive Cards' inlines: each run carries a semantic color *role* (`color:"accent"`), never a hex — the model for a `{text, tone}` run. <https://learn.microsoft.com/en-us/adaptive-cards/schema-explorer/rich-text-block>
- **Flutter — `ShaderMask`.** The whole-line gradient-text idiom: `srcIn` over opaque white text so the gradient fills the glyph shapes. <https://api.flutter.dev/flutter/widgets/ShaderMask-class.html>
- **Flutter — `WidgetSpan`.** An inline gradient run rides a baseline-aligned `WidgetSpan` so the shader is scoped to the run's own laid-out bounds — no `createShader(Rect)` estimation. <https://api.flutter.dev/flutter/widgets/WidgetSpan-class.html>
