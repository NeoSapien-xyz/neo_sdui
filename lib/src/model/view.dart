import 'package:meta/meta.dart';

import 'block_node.dart';

/// How a sub-view is presented when navigated to.
///
/// One mechanism serves both consumers: `sheet` is how_to's modal bottom sheet,
/// `screen` is the MCP guide's full-screen push. The engine renders the blocks;
/// the app honors the [NeoViewPresent] hint (it owns the Navigator).
enum NeoViewPresent {
  sheet,
  screen;

  static NeoViewPresent fromWire(Object? raw) =>
      raw == 'screen' ? NeoViewPresent.screen : NeoViewPresent.sheet;
}

/// A named sub-view: an ordered block list plus a presentation hint.
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
