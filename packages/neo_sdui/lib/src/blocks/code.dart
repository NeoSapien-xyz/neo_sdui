import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_styles.dart';
import '_motion.dart';

/// code: monospace content with a tap-to-copy affordance — the zero-dependency
/// core floor for exact strings the user must reproduce (shell commands, server
/// URLs, config). `content` is required; optional `label` captions it; optional
/// `language` is a hint the floor ignores and the `neo_sdui_syntax` add-on
/// (a last-wins re-register of this same type) reads to colorize. Copy uses
/// `Clipboard.setData` from `flutter/services` — core Flutter, no new package.
/// All look is the theme's: the `mono` type slot, the `surface` role, the accent
/// copy chip. The wire carries no pixels.
Widget buildCode(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  final content = node.stringOr('content', '')!;
  final label = node.stringOr('label');
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (label != null) ...[
        Text(label, style: theme.caption),
        SizedBox(height: theme.spaceSm),
      ],
      _CopyableCode(content: content),
    ],
  );
}

/// The copyable code surface on its own — reused by `steps` for a command
/// attached to a step item (no envelope of its own). Same widget the `code`
/// block wraps, so the two share look and copy behavior.
Widget codeChip(String content) => _CopyableCode(content: content);

/// The copyable surface: mono content + a Copy chip that flips to a "Copied"
/// confirmation for [_confirmFor] after a tap. Stateful only for that transient
/// acknowledgement (a short, bounded timer — KTD9).
class _CopyableCode extends StatefulWidget {
  const _CopyableCode({required this.content});

  final String content;

  @override
  State<_CopyableCode> createState() => _CopyableCodeState();
}

class _CopyableCodeState extends State<_CopyableCode> {
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
    final s = theme.code;
    final mono = s.textStyle ?? theme.mono.copyWith(color: theme.textPrimary);
    final text = Text(widget.content,
        style: mono, softWrap: s.wrap, maxLines: s.wrap ? null : 1);
    final glyph = s.copyGlyph;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.fill ?? theme.surface,
        border: s.border == null ? null : Border.fromBorderSide(s.border!),
        borderRadius: s.radius ?? theme.radiusMd,
      ),
      child: glyph == null
          ? Padding(
              padding: s.padding ?? EdgeInsets.all(theme.spaceMd),
              child: Row(
                children: [
                  Expanded(child: _scrolled(s, text)),
                  SizedBox(width: theme.spaceSm),
                  _CopyChip(copied: _copied, onTap: _copy),
                ],
              ),
            )
          : Stack(
              children: [
                Padding(
                  padding: s.padding ?? EdgeInsets.all(theme.spaceMd),
                  child: _scrolled(s, text),
                ),
                Positioned(
                  top: s.copyInset,
                  right: s.copyInset,
                  child: PressScale(
                    onTap: _copy,
                    scale: 0.9,
                    child: Container(
                      key: const Key('code-copy'),
                      width: s.copySize,
                      height: s.copySize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.copyFill,
                        border: s.copyBorder == null
                            ? null
                            : Border.fromBorderSide(s.copyBorder!),
                        borderRadius: s.copyRadius ?? theme.radiusSm,
                      ),
                      child: glyph(15, _copied ? theme.accent : theme.textMuted),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _scrolled(NeoCodeStyle s, Widget text) => s.wrap
      ? text
      : SingleChildScrollView(scrollDirection: Axis.horizontal, child: text);
}

/// Accent-tinted pill: "Copy" -> "Copied" after a tap. Fill and text derive from
/// the accent role (via `toneSurface`), so a re-skin recolors it with no wire
/// change.
class _CopyChip extends StatelessWidget {
  const _CopyChip({required this.copied, required this.onTap});

  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    final label =
        theme.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w600);
    return PressScale(
      onTap: onTap,
      // A small control dips hard — the same absolute travel that reads as a
      // nudge on a full card would be invisible at chip size.
      scale: 0.9,
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
