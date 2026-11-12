import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';
import '_icon.dart';
import '_motion.dart';

/// accordion: a titled section that holds any child blocks and starts closed.
/// Tapping the head opens it; the body fades and rises in. Open state is
/// client-owned. Children go through the scope's `buildBlocks`, so a child that
/// throws is isolated and its siblings still render. An old app that lacks the
/// type renders the block's `fallback` instead.
Widget buildAccordion(BuildContext context, BlockNode node) =>
    _Accordion(title: node.fields['title'], children: node.nodeList('children'));

class _Accordion extends StatefulWidget {
  const _Accordion({required this.title, required this.children});

  final Object? title;
  final List<BlockNode> children;

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    final scope = NeoSduiScope.of(context);
    final theme = scope.theme;
    final style = theme.accordion;
    final border = theme.stepCardBorderColor;
    final head = Semantics(
      button: true,
      expanded: _open,
      label: _plain(widget.title),
      onTap: _toggle,
      excludeSemantics: true,
      child: PressScale(
        onTap: _toggle,
        scale: 0.994,
        child: Padding(
          padding: style.headPadding,
          child: Row(
            children: [
              Expanded(
                child: neoText(
                  theme,
                  widget.title,
                  (style.titleStyle ?? theme.resolvedPanelTitle)
                      .copyWith(color: theme.textPrimary),
                ),
              ),
              SizedBox(width: style.headGap),
              TurningCaret(
                open: _open,
                openTurns: 0.5,
                closedColor: theme.textMuted,
                openColor: theme.accent,
                glyph: (color) =>
                    style.chevron?.call(style.chevronSize, color) ??
                    NeoChevronDownIcon(size: style.chevronSize, color: color),
              ),
            ],
          ),
        ),
      ),
    );
    final kids = _open ? scope.buildBlocks(widget.children) : const <Widget>[];
    final body = SwapFade(
      child: _open
          ? Padding(
              key: const ValueKey(true),
              padding: style.bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < kids.length; i++) ...[
                    if (i > 0) SizedBox(height: theme.blockSpacing),
                    kids[i],
                  ],
                ],
              ),
            )
          : const SizedBox(key: ValueKey(false), width: double.infinity),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardGradient == null ? theme.surface : null,
        gradient: theme.cardGradient,
        borderRadius: theme.radiusLg,
        border: border == null ? null : Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: theme.radiusLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [head, body],
        ),
      ),
    );
  }
}

/// The title as plain text, for the screen reader (runs joined).
String _plain(Object? title) {
  if (title is String) return title;
  if (title is! List) return '';
  return [
    for (final r in title)
      if (r is String) r else if (r is Map && r['text'] is String) r['text'],
  ].join();
}
