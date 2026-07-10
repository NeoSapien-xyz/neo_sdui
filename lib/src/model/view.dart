import 'package:meta/meta.dart';

import 'block_node.dart';

/// How a sub-view opens: `sheet` = modal (how_to), `screen` = push (MCP).
enum NeoViewPresent {
  sheet,
  screen;

  static NeoViewPresent fromWire(Object? raw) =>
      raw == 'screen' ? NeoViewPresent.screen : NeoViewPresent.sheet;
}

/// A named sub-view: blocks + how it opens. The app owns the Navigator.
@immutable
class NeoView {
  const NeoView({required this.present, required this.blocks});

  final NeoViewPresent present;
  final List<BlockNode> blocks;

  factory NeoView.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    return NeoView(
      present: NeoViewPresent.fromWire(json['present']),
      blocks: rawBlocks is List
          ? [
              for (final b in rawBlocks)
                if (b is Map) BlockNode.fromJson(Map<String, Object?>.from(b)),
            ]
          : const [],
    );
  }
}
