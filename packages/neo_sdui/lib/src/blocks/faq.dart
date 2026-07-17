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
  Widget _row(NeoSduiTheme theme, int i, Map<String, Object?> item,
      {required bool last}) {
    final isOpen = _open.contains(i);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PressScale(
          onTap: () => setState(() => isOpen ? _open.remove(i) : _open.add(i)),
          scale: 0.994,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
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
                        style: theme.body.copyWith(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _caret(theme, isOpen),
                  ],
                ),
                AnimatedSize(
                  duration:
                      theme.reduceMotion ? Duration.zero : theme.swapDuration,
                  curve: theme.motionCurve,
                  alignment: Alignment.topLeft,
                  child: isOpen
                      ? Padding(
                          padding: EdgeInsets.only(top: theme.spaceSm),
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
                            child:
                                Text(_str(item['answer']), style: theme.body),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
        if (!last)
          Container(
            height: 1,
            color: theme.divider ?? theme.onSurface.withValues(alpha: 0.1),
          ),
      ],
    );
  }

  /// The row's chevron: points right + primary when collapsed; rotates down +
  /// turns accent when open (the figma affordance). A plain `›` glyph — its
  /// size is a UI constant like an icon's, its colors are theme roles.
  Widget _caret(NeoSduiTheme theme, bool open) {
    // Rotated + tinted over the same beat as the expand, so the affordance and
    // the answer arrive together. A RotatedBox would snap: it re-lays-out at a
    // fixed quarter turn rather than animating through one.
    final duration = theme.reduceMotion ? Duration.zero : theme.swapDuration;
    return SizedBox(
      width: 24,
      height: 24,
      child: Center(
        child: AnimatedRotation(
          turns: open ? 0.25 : 0,
          duration: duration,
          curve: theme.motionCurve,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: open ? theme.accent : theme.textPrimary),
            duration: duration,
            curve: theme.motionCurve,
            builder: (context, color, child) => Text(
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
          ),
        ),
      ),
    );
  }
}
