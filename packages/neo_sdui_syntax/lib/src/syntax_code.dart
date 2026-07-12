import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

/// The highlighted, copyable surface. Identical copy behavior to the core
/// `code` block (Clipboard + a "Copied" confirmation); the only difference is
/// the content is rendered through [_highlight] instead of a plain mono `Text`.
class _SyntaxCode extends StatefulWidget {
  const _SyntaxCode({required this.content, this.language});

  final String content;
  final String? language;

  @override
  State<_SyntaxCode> createState() => _SyntaxCodeState();
}

class _SyntaxCodeState extends State<_SyntaxCode> {
  static const _confirmFor = Duration(seconds: 2);
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    await HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(_confirmFor, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.surface, borderRadius: theme.radiusMd),
      child: Padding(
        padding: EdgeInsets.all(theme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.language != null) ...[
              _LanguageBadge(language: widget.language!),
              SizedBox(height: theme.spaceSm),
            ],
            Row(
              children: [
                Expanded(child: _highlight(theme, widget.content, widget.language)),
                SizedBox(width: theme.spaceSm),
                _CopyChip(copied: _copied, onTap: _copy),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder highlighter: renders the content in the theme's mono slot.
///
// ponytail: this is the one seam that changes when highlighting goes real —
// replace the mono `Text` with `flutter_highlight`'s
// `HighlightView(content, language: language ?? 'plaintext', theme: <map>)`,
// derive the theme map from the role palette (accent/textPrimary/textMuted),
// and keep everything above (surface, badge, copy chip) as-is.
Widget _highlight(NeoSduiTheme theme, String content, String? language) =>
    Text(content, style: theme.mono.copyWith(color: theme.textPrimary));

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

/// Accent-tinted pill: "Copy" -> "Copied" after a tap (mirrors the core block).
class _CopyChip extends StatelessWidget {
  const _CopyChip({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    final label =
        theme.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w600);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.toneSurface('accent'),
          borderRadius: theme.radiusSm,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            copied ? 'Copied' : 'Copy',
            key: const Key('code-copy'),
            style: label,
          ),
        ),
      ),
    );
  }
}
