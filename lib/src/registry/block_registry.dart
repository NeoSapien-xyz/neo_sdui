import 'package:flutter/widgets.dart';

import '../model/block_node.dart';

/// Builds a widget for one block. Reads styling from the ambient `NeoSduiScope`
/// (theme is not threaded through here) and reports taps via the ambient action
/// dispatcher, so a builder signature stays tiny and stable.
typedef BlockBuilder = Widget Function(BuildContext context, BlockNode node);

/// Maps a wire `type` string to the widget that renders it.
///
/// This is the extension seam (R9): the core seeds the roster, and an add-on
/// package calls [register] to contribute its own block type without the core
/// ever importing the add-on. It is the same name -> builder shape rfw uses for
/// its `LocalWidgetLibrary`.
class BlockRegistry {
  BlockRegistry._(this._builders);

  /// An empty registry. Use [copy] + [register] to extend a seeded one.
  factory BlockRegistry.empty() => BlockRegistry._(<String, BlockBuilder>{});

  final Map<String, BlockBuilder> _builders;

  /// The builder for [type], or null when nothing is registered — the render
  /// pipeline routes a null to the block's `fallback`, else skips it.
  BlockBuilder? builderFor(String type) => _builders[type];

  bool contains(String type) => _builders.containsKey(type);

  /// Register (or override) a builder. Overriding lets an add-on replace a core
  /// block; last registration wins.
  void register(String type, BlockBuilder builder) => _builders[type] = builder;

  /// A detached copy — register on it without mutating the original (so an app
  /// can extend the default roster per renderer instance).
  BlockRegistry copy() => BlockRegistry._(Map.of(_builders));
}
