import 'package:flutter/widgets.dart';

import '../action/neo_action.dart';
import '../blocks/default_registry.dart';
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
class NeoSduiView extends StatelessWidget {
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
  static final BlockRegistry _defaults = defaultRegistry();
  BlockRegistry get _registry => registry ?? _defaults;

  /// Compiled-in floor rendered when [document] produces zero blocks.
  final NeoDocument? defaultDocument;

  final NeoViewPresenter? onPresentSheet;
  final NeoViewPresenter? onPresentScreen;

  /// Feature -> supported major version, for a block's `requires`.
  final Map<String, int> capabilities;

  @override
  Widget build(BuildContext context) {
    var content = _buildBlocks(document.blocks);
    if (content.isEmpty && defaultDocument != null) {
      content = _buildBlocks(defaultDocument!.blocks);
    }
    return NeoSduiScope(
      theme: theme,
      dispatch: _dispatch,
      buildBlocks: _buildBlocks,
      // Backdrop fills the whole view (behind any transparent app bar); the
      // scroll content sits inside a SafeArea so a host that extends the body
      // behind system chrome keeps content clear of it. No insets -> no-op, so
      // goldens (zero-padding MediaQuery) are byte-identical.
      child: _backdrop(
        child: SafeArea(
          child: ListView.separated(
            padding: theme.contentPadding +
                EdgeInsets.symmetric(vertical: theme.blockSpacing),
            itemCount: content.length,
            separatorBuilder: (_, _) => SizedBox(height: theme.blockSpacing),
            itemBuilder: (_, i) => content[i],
          ),
        ),
      ),
    );
  }

  /// Paints the screen backdrop: the flat [NeoSduiTheme.background] via a plain
  /// ColoredBox, or [NeoSduiTheme.backgroundGradient] via a DecoratedBox when the
  /// theme sets one. Flat is the default — byte-identical to the pre-gradient
  /// render, so no goldens regenerate.
  Widget _backdrop({required Widget child}) {
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
    final usable = node.isValidType &&
        _registry.contains(node.type) &&
        _requiresMet(node.requires);
    if (!usable) {
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
      final have = capabilities[e.key];
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
        final view = document.viewById(id);
        if (view == null) return;
        final child = _subView(view);
        (present == NeoViewPresent.sheet ? onPresentSheet : onPresentScreen)
            ?.call(ctx, view, child);
      case ExternalUrl():
      case RouteAction():
      case CloseView():
      case CloseAll():
      case InvalidAction():
        onAction(ctx, action);
    }
  }

  /// A sub-view is just another NeoSduiView over the view's blocks, carrying the
  /// same `views` map so its own actions still resolve.
  NeoSduiView _subView(NeoView view) => NeoSduiView(
        document: NeoDocument(
          version: document.version,
          blocks: view.blocks,
          views: document.views,
        ),
        theme: theme,
        registry: registry,
        onAction: onAction,
        onPresentSheet: onPresentSheet,
        onPresentScreen: onPresentScreen,
        capabilities: capabilities,
      );
}
