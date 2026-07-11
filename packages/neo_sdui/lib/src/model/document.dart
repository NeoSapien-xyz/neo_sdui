import 'package:meta/meta.dart';

import 'block_node.dart';
import 'view.dart';

/// A whole guide from one Remote Config key: `{version, blocks, views}`.
/// The app decodes the JSON and passes the map in; this package never does IO.
@immutable
class NeoDocument {
  const NeoDocument({
    required this.version,
    required this.blocks,
    this.views = const {},
  });

  final int version;
  final List<BlockNode> blocks;
  final Map<String, NeoView> views;

  factory NeoDocument.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    final rawViews = json['views'];
    return NeoDocument(
      version: json['version'] is int ? json['version'] as int : 0,
      blocks: rawBlocks is List
          ? [
              for (final b in rawBlocks)
                if (b is Map) BlockNode.fromJson(Map<String, Object?>.from(b)),
            ]
          : const [],
      views: rawViews is Map
          ? {
              for (final entry in rawViews.entries)
                if (entry.key is String && entry.value is Map)
                  entry.key as String: NeoView.fromJson(
                    Map<String, Object?>.from(entry.value as Map),
                  ),
            }
          : const {},
    );
  }

  NeoView? viewById(String id) => views[id];
}
