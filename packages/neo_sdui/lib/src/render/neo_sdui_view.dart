import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../blocks/_motion.dart';
import '../blocks/default_registry.dart';
import '../blocks/tabs.dart';
import '../model/block_node.dart';
import '../model/document.dart';
import '../model/view.dart';
import '../registry/block_registry.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';

/// App resolves a non-view action (external url, route, close).
typedef NeoActionHandler = void Function(BuildContext context, NeoAction action);

/// App presents a sub-view (showModalBottomSheet / Navigator.push). [view]
/// carries the sub-view metadata (its [NeoView.title] for the app bar); [child]
/// is the built widget to host.
typedef NeoViewPresenter = void Function(
    BuildContext context, NeoView view, Widget child);

/// Renders one document (or sub-view) into a themed, scrollable block list.
///
/// Resilient pipeline: unknown / unsatisfiable / throwing block -> its
/// `fallback`, else skipped. If nothing renders, falls back to
/// [defaultDocument] so the user never sees a blank screen.
///
/// Stateful only to own a [ValueNotifier] per top-level `tabs` block: the pinned
/// tab strip and the content scrolling beneath it are separate slivers, so their
/// shared selection has to live above the scroll view (here) rather than inside a
/// single tabs widget.
class NeoSduiView extends StatefulWidget {
  const NeoSduiView({
    required this.document,
    required this.theme,
    required this.onAction,
    this.registry,
    this.defaultDocument,
    this.onPresentSheet,
    this.onPresentScreen,
    this.capabilities = const {},
    super.key,
  });

  final NeoDocument document;
  final NeoSduiTheme theme;
  final NeoActionHandler onAction;

  /// Core roster when null. Built once and shared (read-only).
  final BlockRegistry? registry;

  /// Compiled-in floor rendered when [document] produces zero blocks.
  final NeoDocument? defaultDocument;

  final NeoViewPresenter? onPresentSheet;
  final NeoViewPresenter? onPresentScreen;

  /// Feature -> supported major version, for a block's `requires`.
  final Map<String, int> capabilities;

  @override
  State<NeoSduiView> createState() => _NeoSduiViewState();
}

class _NeoSduiViewState extends State<NeoSduiView> {
  static final BlockRegistry _defaults = defaultRegistry();
  BlockRegistry get _registry => widget.registry ?? _defaults;

  /// One selection per top-level `tabs` block, keyed by its index in
  /// [NeoDocument.blocks]. Created lazily, disposed on unmount.
  final Map<int, ValueNotifier<int>> _tabSelection = {};
  ValueNotifier<int> _selectionFor(int index) =>
      _tabSelection.putIfAbsent(index, () => ValueNotifier<int>(0));

  @override
  void dispose() {
    for (final n in _tabSelection.values) {
      n.dispose();
    }
    super.dispose();
  }

  /// [theme], with the platform's "reduce motion" switch folded in.
  ///
  /// That switch is an accessibility signal, not a look choice, so it lands here
  /// rather than waiting on each client to wire it up — a client that forgets
  /// would otherwise animate at a user who asked it not to. It only ever turns
  /// motion *off*: a theme with [NeoSduiTheme.reduceMotion] already set stays as
  /// it is, so the app keeps its own kill switch (KTD9).
  ///
  /// Returns the very same instance when nothing changes — [NeoSduiScope]
  /// notifies on a new theme identity, so a fresh copy per build would rebuild
  /// every block for nothing. (Free of a MediaQuery ancestor check: the SafeArea
  /// below already requires one.)
  NeoSduiTheme? _reducedSource;
  NeoSduiTheme? _reducedTheme;

  NeoSduiTheme _themeFor(BuildContext context) {
    if (widget.theme.reduceMotion || !MediaQuery.disableAnimationsOf(context)) {
      return widget.theme;
    }
    // Memoize the reduce-motion copy on the identity of `widget.theme`: a rebuild
    // while the OS "disable animations" switch is on must not mint a fresh theme
    // every time, or the new identity makes NeoSduiScope rebuild every block for
    // nothing (the very churn the doc comment above warns about).
    if (!identical(_reducedSource, widget.theme)) {
      _reducedSource = widget.theme;
      _reducedTheme = widget.theme.copyWith(reduceMotion: true);
    }
    return _reducedTheme!;
  }

  /// A node the renderer can actually build: known type, a registered builder,
  /// and its capability gate met. Shared by [_buildOne] and [_isPinnableTabs] so
  /// the two can never disagree on whether a block is renderable.
  bool _usable(BlockNode node) =>
      node.isValidType &&
      _registry.contains(node.type) &&
      _requiresMet(node.requires);

  /// A top-level `tabs` block that pins its strip. Requires at least one tab — an
  /// empty `tabs` routed to the sliver path would never reach the
  /// [NeoSduiView.defaultDocument] blank-screen fallback that only [_listScroll]
  /// runs, silently defeating the "never blank" guarantee.
  bool _isPinnableTabs(BlockNode node) =>
      node.type == 'tabs' && _usable(node) && node.mapList('tabs').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = _themeFor(context);
    final nodes = widget.document.blocks;
    // A top-level tabs block pins its strip, which needs a CustomScrollView. No
    // such block -> the plain ListView path, byte-identical to the pre-pinning
    // render (so every non-tabs golden stays put).
    final scroll = nodes.any(_isPinnableTabs)
        ? _tabbedScroll(context, theme, nodes)
        : _listScroll(theme);
    return NeoSduiScope(
      theme: theme,
      dispatch: _dispatch,
      buildBlocks: _buildBlocks,
      // Backdrop fills the whole view (behind any transparent app bar); the
      // scroll content sits inside a SafeArea so a host that extends the body
      // behind system chrome keeps content clear of it. No insets -> no-op, so
      // goldens (zero-padding MediaQuery) are byte-identical.
      child: _backdrop(
        theme,
        child: SafeArea(child: scroll),
      ),
    );
  }

  /// The default path: a flat, separated block list.
  Widget _listScroll(NeoSduiTheme theme) {
    var content = _buildBlocks(widget.document.blocks);
    if (content.isEmpty && widget.defaultDocument != null) {
      content = _buildBlocks(widget.defaultDocument!.blocks);
    }
    return ListView.separated(
      padding: theme.contentPadding +
          EdgeInsets.symmetric(vertical: theme.blockSpacing),
      itemCount: content.length,
      separatorBuilder: (_, _) => SizedBox(height: theme.blockSpacing),
      // Only a *top-level* block stages its entrance. Blocks nested inside a tab
      // or group arrive with their parent, which already animated.
      itemBuilder: (_, i) =>
          entrance(index: i, theme: theme, child: content[i]),
    );
  }

  /// The pinned-tabs path: consecutive normal blocks collapse into padded,
  /// separated sliver lists; each top-level tabs block splits into a pinned strip
  /// header + its content (see [tabsPinnedSlivers]).
  Widget _tabbedScroll(
      BuildContext context, NeoSduiTheme theme, List<BlockNode> nodes) {
    final slivers = <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: theme.blockSpacing)),
    ];
    final run = <Widget>[];
    // Entrance index counts only *rendered* top-level blocks (matching
    // _listScroll), so a skipped block or the pinned tabs block itself never
    // leaves a gap in the stagger wave.
    var visible = 0;

    void flushRun() {
      if (run.isEmpty) return;
      final items = List<Widget>.of(run);
      run.clear();
      slivers.add(
        SliverPadding(
          padding: theme.contentPadding,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              // Interleave `blockSpacing` separators between items (index odd).
              (_, i) => i.isOdd
                  ? SizedBox(height: theme.blockSpacing)
                  : items[i ~/ 2],
              childCount: items.length * 2 - 1,
            ),
          ),
        ),
      );
    }

    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (_isPinnableTabs(node)) {
        flushRun();
        if (slivers.length > 1) {
          slivers
              .add(SliverToBoxAdapter(child: SizedBox(height: theme.blockSpacing)));
        }
        slivers.addAll(
          tabsPinnedSlivers(
              context, node, _buildBlocks, _selectionFor(i), theme),
        );
      } else {
        final w = _buildOne(node);
        if (w != null) run.add(entrance(index: visible++, theme: theme, child: w));
      }
    }
    flushRun();
    slivers.add(SliverToBoxAdapter(child: SizedBox(height: theme.blockSpacing)));

    return CustomScrollView(slivers: slivers);
  }

  /// Paints the screen backdrop: the flat [NeoSduiTheme.background] via a plain
  /// ColoredBox, or [NeoSduiTheme.backgroundGradient] via a DecoratedBox when the
  /// theme sets one. Flat is the default — byte-identical to the pre-gradient
  /// render, so no goldens regenerate.
  Widget _backdrop(NeoSduiTheme theme, {required Widget child}) {
    final gradient = theme.backgroundGradient;
    if (gradient == null) return ColoredBox(color: theme.background, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child,
    );
  }

  List<Widget> _buildBlocks(List<BlockNode> nodes) {
    final out = <Widget>[];
    for (final node in nodes) {
      final w = _buildOne(node);
      if (w != null) out.add(w);
    }
    return out;
  }

  /// Null means skip this block entirely.
  Widget? _buildOne(BlockNode node) {
    if (!_usable(node)) {
      return node.fallback == null ? null : _buildOne(node.fallback!);
    }
    return Builder(builder: (ctx) {
      try {
        return _registry.builderFor(node.type)!(ctx, node);
      } catch (_) {
        final fb = node.fallback == null ? null : _buildOne(node.fallback!);
        return fb ?? const SizedBox.shrink();
      }
    });
  }

  bool _requiresMet(Map<String, String>? requires) {
    if (requires == null) return true;
    for (final e in requires.entries) {
      final have = widget.capabilities[e.key];
      if (have == null) return false;
      // Fail closed: an unparseable required version (e.g. "v2", "beta") means
      // "can't satisfy" -> unmet -> fallback, never silently satisfied.
      final need = int.tryParse(e.value.split('.').first);
      if (need == null || have < need) return false;
    }
    return true;
  }

  void _dispatch(BuildContext ctx, NeoAction action) {
    switch (action) {
      case OpenView(:final id, :final present):
        final view = widget.document.viewById(id);
        if (view == null) return;
        final child = _subView(view);
        (present == NeoViewPresent.sheet
                ? widget.onPresentSheet
                : widget.onPresentScreen)
            ?.call(ctx, view, child);
      case ExternalUrl():
      case RouteAction():
      case CloseView():
      case CloseAll():
      case InvalidAction():
        widget.onAction(ctx, action);
    }
  }

  /// A sub-view is just another NeoSduiView over the view's blocks, carrying the
  /// same `views` map so its own actions still resolve.
  NeoSduiView _subView(NeoView view) => NeoSduiView(
        document: NeoDocument(
          version: widget.document.version,
          blocks: view.blocks,
          views: widget.document.views,
        ),
        theme: widget.theme,
        registry: widget.registry,
        onAction: widget.onAction,
        onPresentSheet: widget.onPresentSheet,
        onPresentScreen: widget.onPresentScreen,
        capabilities: widget.capabilities,
      );
}
