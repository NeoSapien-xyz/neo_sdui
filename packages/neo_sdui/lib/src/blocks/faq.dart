import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_motion.dart';

/// faq: accordion of question/answer pairs. Open state is client-owned (KTD9).
Widget buildFaq(BuildContext context, BlockNode node) =>
    _Faq(items: node.mapList('items'));

/// Safe read for a raw-map field: a non-string value (an authoring slip like an
/// unquoted number) degrades to '' instead of throwing an `as String` cast at
/// mount — matching the guarded `stringOr` reads every other block uses.
String _str(Object? v) => v is String ? v : '';

class _Faq extends StatefulWidget {
  const _Faq({required this.items});
  final List<Map<String, Object?>> items;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  final _open = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          _row(theme, i, widget.items[i], last: i == widget.items.length - 1),
      ],
    );
  }

  /// One accordion row: a question row (white question + a chevron affordance)
  /// that toggles the muted answer open, with a hairline divider under every
  /// item but the last (the figma FAQ list). All look is theme roles.
  Widget _row(
    NeoSduiTheme theme,
    int i,
    Map<String, Object?> item, {
    required bool last,
  }) {
    final style = theme.faq;
    final isOpen = _open.contains(i);
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PressScale(
          onTap: () => setState(() => isOpen ? _open.remove(i) : _open.add(i)),
          scale: 0.994,
          child: Padding(
            padding: style.questionPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _str(item['question']),
                        // A question reads as a heading — primary (white),
                        // medium — not the muted body color.
                        style: theme.resolvedPanelTitle.copyWith(
                          color: theme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _caret(theme, isOpen),
                  ],
                ),
                _expand(
                  theme,
                  child: isOpen
                      ? Padding(
                          padding: style.answerPadding ??
                              EdgeInsets.only(top: theme.spaceSm),
                          // The answer fades in *with* the expand rather than
                          // riding it fully opaque — text sliding out from under
                          // the question at full strength reads as a reveal.
                          // Tweened on mount, not AnimatedOpacity: the answer is
                          // built at full opacity when it opens, and an implicit
                          // fade needs a *change* to animate, so it would sit
                          // there at 1 and never run.
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: theme.reduceMotion
                                ? Duration.zero
                                : theme.swapDuration,
                            curve: theme.motionCurve,
                            builder: (context, opacity, child) =>
                                Opacity(opacity: opacity, child: child),
                            // Answer sits in the muted body role (the figma
                            // #868686 paragraph) — the theme owns the exact hue.
                            child: Text(
                              _str(item['answer']),
                              style: style.answerStyle ?? theme.body,
                            ),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        if (!last && style.itemDecoration == null)
          Container(
            height: 1,
            color: theme.divider ?? theme.onSurface.withValues(alpha: 0.1),
          ),
      ],
    );
    final decoration = style.itemDecoration;
    if (decoration == null) return row;
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : style.itemGap),
      child: DecoratedBox(decoration: decoration, child: row),
    );
  }

  /// Animates the answer's height. Reduced motion skips the AnimatedSize: a
  /// zero-duration one finishes inside its own layout and trips a debug assert.
  Widget _expand(NeoSduiTheme theme, {required Widget child}) =>
      theme.reduceMotion
          ? child
          : AnimatedSize(
              duration: theme.swapDuration,
              curve: theme.motionCurve,
              alignment: Alignment.topLeft,
              child: child,
            );

  /// The row's chevron: points right + [NeoFaqStyle.caretColor] when collapsed;
  /// turns [NeoFaqStyle.openTurns] + accent when open. A plain `›` unless the
  /// theme supplies a glyph — its size is a UI constant like an icon's, its
  /// colors are theme roles.
  Widget _caret(NeoSduiTheme theme, bool open) {
    final style = theme.faq;
    return TurningCaret(
      open: open,
      openTurns: style.openTurns,
      closedColor: style.caretColor ?? theme.textPrimary,
      openColor: theme.accent,
      glyph: (color) =>
          style.caretGlyph?.call(22, color) ??
          Text(
            '›',
            // geometry: sizes the '›' glyph inside its 24px box — icon
            // metrics, not the type scale. Not the theme's to set.
            style: theme.body.copyWith(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w400,
              height: 1,
            ),
          ),
    );
  }
}
