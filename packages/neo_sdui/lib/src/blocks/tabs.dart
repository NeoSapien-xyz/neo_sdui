import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_gradient_text.dart';

/// tabs: a label strip + the selected tab's child blocks. Widgets-only (no
/// Material TabBar) so it stays free of ThemeData. Selection is client-owned.
Widget buildTabs(BuildContext context, BlockNode node) {
  final tabs = [
    for (final t in node.mapList('tabs'))
      (
        label: t['label'] as String? ?? '',
        blocks: [
          for (final b in (t['blocks'] as List? ?? const []))
            if (b is Map) BlockNode.fromJson(Map<String, Object?>.from(b)),
        ],
      ),
  ];
  return _Tabs(tabs: tabs);
}

typedef _Tab = ({String label, List<BlockNode> blocks});

class _Tabs extends StatefulWidget {
  const _Tabs({required this.tabs});
  final List<_Tab> tabs;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final scope = NeoSduiScope.of(context);
    final theme = scope.theme;
    if (widget.tabs.isEmpty) return const SizedBox.shrink();
    final selected = _selected.clamp(0, widget.tabs.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segmented control: a rounded track holding equal-width segments; the
        // selected one gets a raised pill + accent label, the rest muted text.
        // Track/pill pixels are theme roles (surface, its lighten, radii) — the
        // wire carries only the labels.
        DecoratedBox(
          decoration:
              BoxDecoration(color: theme.surface, borderRadius: theme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                for (var i = 0; i < widget.tabs.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: i == selected
                              ? theme.shimmerHighlight
                              : const Color(0x00000000),
                          borderRadius: theme.radiusSm,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: i == selected
                                ? neoText(theme, widget.tabs[i].label, theme.body,
                                    tone: 'accent')
                                : Text(widget.tabs[i].label,
                                    style:
                                        theme.body.copyWith(color: theme.textMuted)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: theme.spaceMd),
        ...scope.buildBlocks(widget.tabs[selected].blocks),
      ],
    );
  }
}
