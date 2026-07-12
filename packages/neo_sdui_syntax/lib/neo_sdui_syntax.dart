/// neo_sdui_syntax — an add-on that re-registers the core `code` block to
/// syntax-highlight its content by `language`, while keeping the copy affordance.
///
/// Scaffold status: the extension path — `NeoSdui.compose` + a last-wins
/// re-register of `code` — is complete and tested. The highlighter itself is a
/// placeholder (a language badge over mono content); swap it for
/// `flutter_highlight`'s `HighlightView` in `src/syntax_code.dart` when wire
/// content actually needs coloring. Absent this add-on, the core `code` floor
/// (mono + copy) renders unchanged.
///
/// Install: `NeoSdui.compose([neoSduiSyntaxAddon])`.
library;

// Builder stays registry-only (it lives in src/syntax_code.dart, unexported) —
// expose just the add-on.
export 'src/syntax_addon.dart';
