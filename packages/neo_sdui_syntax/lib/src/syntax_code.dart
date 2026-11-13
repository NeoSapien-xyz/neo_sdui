import 'package:flutter/widgets.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// The add-on's `code` builder: same semantics as the core floor (`content`
/// required, optional `label`), but it reads `language` — which the core floor
/// ignores — to syntax-highlight the content. Reads only the theme for look,
/// exactly like the core block; the wire carries no pixels.
Widget buildSyntaxCode(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final content = node.stringOr('content', '')!;
  final language = node.stringOr('language');
  final label = node.stringOr('label');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Text(label, style: theme.caption),
        SizedBox(height: theme.spaceSm),
      ],
      _SyntaxCode(content: content, language: language),
    ],
  );
}

/// The highlighted surface: the core `code` box and copy button (via
/// `neoCodeSurface`) with the content rendered through [_highlight].
class _SyntaxCode extends StatelessWidget {
  const _SyntaxCode({required this.content, this.language});

  final String content;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    // The badge rides inside the code box (top-left), as before the shared
    // surface: the body holds badge + highlighted content.
    return neoCodeSurface(
      content,
      (base) => language == null
          ? _highlight(theme, content, null, base)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguageBadge(language: language!),
                SizedBox(height: theme.spaceSm),
                _highlight(theme, content, language, base),
              ],
            ),
    );
  }
}

/// Real highlighter: `flutter_highlight`'s HighlightView over the atom-one-dark
/// token palette (bright-on-dark, matching the `surface` code envelope). The
/// wire's `language` picks the grammar; absent, default to `bash` — every guide
/// code block today is a shell command. The highlight theme's own root bg is
/// dropped (transparent) so the content sits on the block's `surface`, and the
/// base glyph style is the theme's `mono` slot. Look stays theme-owned; the
/// wire carries only `content` + `language`.
Widget _highlight(NeoSduiTheme theme, String content, String? language, TextStyle base) =>
    HighlightView(
      content,
      language: language ?? 'bash',
      theme: {
        ...atomOneDarkTheme,
        'root': TextStyle(
          backgroundColor: const Color(0x00000000),
          color: theme.textPrimary,
        ),
      },
      padding: EdgeInsets.zero,
      textStyle: base,
    );

/// A small accent chip naming the language — the visible proof the add-on read
/// a wire field the core floor ignored.
class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.toneSurface('accent'),
        borderRadius: theme.radiusSm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          language,
          key: const Key('syntax-language'),
          style: theme.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
