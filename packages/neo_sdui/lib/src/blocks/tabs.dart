import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_motion.dart';
import 'header.dart' show HeadingLevel, HeadingScale;
import '_neumorphic.dart';

/// tabs: a label strip + the selected tab's child blocks. Widgets-only (no
/// Material TabBar) so it stays free of ThemeData. Selection is client-owned.
///
/// Two render forms share one look:
/// - **box** ([buildTabs]) — strip stacked above its content, scrolls as one
///   block. Used when tabs is *nested* (inside a group / another tab).
/// - **pinned** ([tabsPinnedSlivers]) — the strip is a floating pinned header
///   that stays under the app bar while the content scrolls past it. Used when
///   tabs is a *top-level* block (the guide sub-screens). [NeoSduiView] picks
///   this form and owns the shared selection notifier.
Widget buildTabs(BuildContext context, BlockNode node) =>
    _Tabs(tabs: _tabsOf(node), header: node.nodeList('header'));

typedef _Tab = ({String label, List<BlockNode> blocks});

/// The tab list off a `tabs` node — shared by both render forms.
List<_Tab> _tabsOf(BlockNode node) => [
  for (final t in node.mapList('tabs'))
    (
      label: t['label'] as String? ?? '',
      blocks: [
        for (final b in (t['blocks'] as List? ?? const []))
          if (b is Map) BlockNode.fromJson(Map<String, Object?>.from(b)),
      ],
    ),
];

/// The neumorphic segmented control itself: a recessed `tabTrack` groove holding
/// the tabs, the selected one a darker pill pressed into it. All colours are
/// theme roles; the inset geometry is the figma neumorphic spec. Selection is
/// external: [selected] is the current index, [onTap] reports a change (the box
/// form drives it with setState, the pinned form with a ValueNotifier).
Widget _strip(
  NeoSduiTheme theme,
  List<_Tab> tabs,
  int selected,
  ValueChanged<int> onTap,
) {
  final style = theme.tabs;
  final trackInsets = <Inset>[
    if (style.neumorphic) ...[
      Inset(kInsetDark, const Offset(3.5, 3.5), 12),
      Inset(
        theme.onSurface.withValues(alpha: 0.10),
        const Offset(-1.5, -1.5),
        8,
      ),
    ],
  ];
  final pillInsets = <Inset>[
    if (style.neumorphic) ...[
      Inset(kInsetDark, const Offset(-2, -2), 4),
      Inset(theme.onSurface.withValues(alpha: 0.06), const Offset(1, 1), 6),
    ],
  ];
  // The pressed pill sits *darker* than the track (the figma reads a dented
  // segment) — surface barely lifted, well below the lighter `tabTrack`.
  final pillColor =
      style.pillColor ??
      Color.alphaBlend(theme.onSurface.withValues(alpha: 0.03), theme.surface);
  // A faint hairline between two *unselected* neighbours; suppressed next to the
  // pill, which owns that edge.
  final divider = theme.onSurface.withValues(alpha: 0.06);

  return neumorphic(
    radius: style.trackRadius ?? theme.radiusMd,
    color: style.trackColor ?? theme.tabTrack,
    border: style.trackBorder == null
        ? null
        : Border.fromBorderSide(style.trackBorder!),
    insets: trackInsets,
    child: Padding(
      padding: style.trackPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0 && style.gap > 0) SizedBox(width: style.gap),
            if (style.neumorphic && i > 0 && selected != i && selected != i - 1)
              Container(width: 1, height: 20, color: divider),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: i == selected
                    ? neumorphic(
                        radius: theme.radiusSm,
                        color: pillColor,
                        border: style.pillBorder == null
                            ? null
                            : Border.fromBorderSide(style.pillBorder!),
                        shadows: style.pillShadow,
                        insets: pillInsets,
                        child: _label(theme, tabs[i].label, true),
                      )
                    : _label(theme, tabs[i].label, false),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// A tab label: the selected one in the accent role (medium), the rest primary
/// white (regular). Tracking rides the `body` role (the figma −0.04em Work Sans
/// tracking), so it stays wired to the theme, not hardcoded here.
Widget _label(NeoSduiTheme theme, String label, bool selected) {
  final style = theme.tabs;
  return Padding(
    padding: style.labelPadding,
    child: Center(
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: style.labelMaxLines,
        overflow: style.labelMaxLines == null ? null : TextOverflow.ellipsis,
        style: (style.labelStyle ?? theme.body).copyWith(
          color: selected
              ? theme.accent
              : (style.unselectedColor ?? theme.textPrimary),
          fontWeight: selected ? FontWeight.w500 : style.unselectedWeight,
        ),
      ),
    ),
  );
}

/// Builds the selected tab's stack: the shared header (rides above every tab)
/// then the chosen tab's own blocks, themed-spaced.
Widget _tabContent(
  NeoSduiTheme theme,
  List<Widget> Function(List<BlockNode>) buildBlocks,
  List<BlockNode> header,
  _Tab tab,
) {
  final blocks = [...buildBlocks(header), ...buildBlocks(tab.blocks)];
  return HeadingScale(
    level: HeadingLevel.subheading,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: theme.blockSpacing),
          blocks[i],
        ],
      ],
    ),
  );
}

/// The selected tab's content, faded + risen in on every selection change (the
/// strip stays put; only this swaps). Both render forms route through here so
/// they can never diverge on the swap — the pinned form used to rebuild content
/// with no transition at all, so the top-level Web/Desktop/Code slider changed
/// pages instantly. [sel] is pre-clamped by the caller; keying on it drives the
/// [SwapFade].
Widget _swapContent(
  NeoSduiTheme theme,
  List<Widget> Function(List<BlockNode>) buildBlocks,
  List<BlockNode> header,
  List<_Tab> tabs,
  int sel,
) => SwapFade(
  child: KeyedSubtree(
    key: ValueKey(sel),
    child: _tabContent(theme, buildBlocks, header, tabs[sel]),
  ),
);

// ── Pinned form ──────────────────────────────────────────────────────────────

/// The top-level slivers for a `tabs` block: a pinned, floating strip header +
/// the selected tab's content. [selected] is owned by [NeoSduiView] (so it
/// survives rebuilds and the header/content share it). The header pins under the
/// app bar; the content scrolls beneath it.
List<Widget> tabsPinnedSlivers(
  BuildContext context,
  BlockNode node,
  List<Widget> Function(List<BlockNode>) buildBlocks,
  ValueNotifier<int> selected,
  NeoSduiTheme theme,
) {
  final tabs = _tabsOf(node);
  if (tabs.isEmpty) return const [];
  final header = node.nodeList('header');
  return [
    SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedStrip(
        theme,
        tabs,
        selected,
        MediaQuery.textScalerOf(context).scale(1),
      ),
    ),
    SliverToBoxAdapter(
      child: ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (context, sel, _) => Padding(
          // Horizontal content inset; a `spaceMd` gap under the pinned pill, and
          // `blockSpacing` below before the next block.
          padding:
              theme.contentPadding +
              EdgeInsets.only(
                top: theme.tabs.contentGap ?? theme.spaceMd,
                bottom: theme.blockSpacing,
              ),
          child: _swapContent(
            theme,
            buildBlocks,
            header,
            tabs,
            sel.clamp(0, tabs.length - 1),
          ),
        ),
      ),
    ),
  ];
}

/// The pinned strip: the floating segmented pill. Full content-width (figma
/// node 4146:14115 is `w-full`, same width as the step cards) — the "floating"
/// reads from the **transparent background** (the guide's backdrop gradient
/// shows through and content scrolls under it), not from a narrowed pill.
class _PinnedStrip extends SliverPersistentHeaderDelegate {
  _PinnedStrip(this.theme, this.tabs, this.selected, this.textScale);
  final NeoSduiTheme theme;
  final List<_Tab> tabs;
  final ValueNotifier<int> selected;

  /// The caller's text scale, folded into the extent. maxExtent/minExtent run
  /// without a BuildContext, so the scale must be passed in, not read from
  /// MediaQuery here.
  final double textScale;

  // Pill (~48) + vertical breathing room at scale 1. Grows with the text so a
  // large accessibility size lifts the header instead of clipping the labels;
  // capped so a 3x scale can't produce a runaway pinned strip.
  // ponytail: linear in scale, 1.6x ceiling — a TextPainter measure would be
  // exact, but this stops the clip without adding a layout pass.
  double get _extent => 68 * textScale.clamp(1.0, 1.6);

  @override
  double get maxExtent => _extent;
  @override
  double get minExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Padding(
      padding: theme.contentPadding + const EdgeInsets.symmetric(vertical: 8),
      child: ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (context, sel, _) => _strip(
          theme,
          tabs,
          sel.clamp(0, tabs.length - 1),
          (i) => selected.value = i,
        ),
      ),
    );
  }

  // The strip renders only the tab *labels* and reflects selection through its
  // own ValueListenableBuilder, so it needs a rebuild only when the theme, the
  // label set, the scale, or the selection notifier identity changes — never per
  // scroll frame. Comparing `tabs` by identity (a fresh list every build) forced
  // exactly that per-frame rebuild.
  @override
  bool shouldRebuild(_PinnedStrip old) =>
      old.theme != theme ||
      old.selected != selected ||
      old.textScale != textScale ||
      _labelsDiffer(old.tabs, tabs);

  static bool _labelsDiffer(List<_Tab> a, List<_Tab> b) {
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i].label != b[i].label) return true;
    }
    return false;
  }
}

// ── Box form (nested tabs) ───────────────────────────────────────────────────

class _Tabs extends StatefulWidget {
  const _Tabs({required this.tabs, this.header = const []});
  final List<_Tab> tabs;
  final List<BlockNode> header;

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

    final strip = _strip(
      theme,
      widget.tabs,
      selected,
      (i) => setState(() => _selected = i),
    );

    // Content faded + risen in on each tap — same swap as the pinned form.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        strip,
        SizedBox(height: theme.tabs.contentGap ?? theme.spaceMd),
        _swapContent(
          theme,
          scope.buildBlocks,
          widget.header,
          widget.tabs,
          selected,
        ),
      ],
    );
  }
}
