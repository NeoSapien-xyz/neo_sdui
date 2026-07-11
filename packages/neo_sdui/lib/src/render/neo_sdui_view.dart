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

/// App presents a sub-view widget (showModalBottomSheet / Navigator.push).
typedef NeoViewPresenter = void Function(BuildContext context, Widget view);

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
      child: ColoredBox(
        color: theme.background,
        child: ListView.separated(
          padding: theme.contentPadding +
              EdgeInsets.symmetric(vertical: theme.blockSpacing),
          itemCount: content.length,
          separatorBuilder: (_, _) => SizedBox(height: theme.blockSpacing),
          itemBuilder: (_, i) => content[i],
        ),
      ),
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
      final need = int.tryParse(e.value.split('.').first) ?? 0;
      if (have < need) return false;
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
            ?.call(ctx, child);
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
