import 'package:flutter/widgets.dart';

import '../model/block_node.dart';

/// Builds a widget for one block. Reads theme + dispatches taps via the ambient
/// `NeoSduiScope`, so the signature stays tiny.
typedef BlockBuilder = Widget Function(BuildContext context, BlockNode node);

/// Maps a wire `type` to its widget builder. Add-ons extend it via
/// copy()+register() without the core importing them (R9).
class BlockRegistry {
  BlockRegistry._(this._builders);

  factory BlockRegistry.empty() => BlockRegistry._(<String, BlockBuilder>{});

  final Map<String, BlockBuilder> _builders;

  /// Builder for [type], or null (pipeline then does fallback/skip).
  BlockBuilder? builderFor(String type) => _builders[type];

  bool contains(String type) => _builders.containsKey(type);

  /// Register or override a builder; last wins (lets add-ons replace a core block).
  void register(String type, BlockBuilder builder) => _builders[type] = builder;

  /// Detached copy — extend without mutating the original.
  BlockRegistry copy() => BlockRegistry._(Map.of(_builders));
}
