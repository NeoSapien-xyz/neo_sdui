# neo_sdui_syntax

A `neo_sdui` add-on that re-registers the core `code` block to **syntax-highlight
its content by `language`**, while keeping the tap-to-copy affordance.

```dart
final composed = NeoSdui.compose([neoSduiSyntaxAddon]);
NeoSduiView(document: doc, registry: composed.registry, theme: theme, onAction: ...);
```

## Wire

Same shape as the core `code` block, plus the `language` hint the core floor
ignores:

```json
{ "type": "code", "label": "Claude Desktop config", "language": "json",
  "content": "{ \"mcpServers\": { \"neosapien\": { } } }" }
```

- Add-on present → highlighted content + a language badge + copy chip.
- Add-on absent → the core floor (mono + copy) renders unchanged. No wire change,
  no crash — the `code` type always resolves to *some* builder.

## Scaffold status

The extension path (compose + last-wins re-register of `code`) is complete and
tested. The **highlighter itself is a placeholder** — `_highlight` in
`lib/src/syntax_code.dart` renders the theme's mono slot with a language badge.
To make it real, add `flutter_highlight` to `pubspec.yaml` and swap that one
function for a `HighlightView`, deriving its color theme from the role palette.
Deferred until wire content needs coloring — see
`docs/plans/2026-07-12-001-feat-neo-sdui-code-block-plan.md`.
