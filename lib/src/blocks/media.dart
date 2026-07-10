import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';

/// how_to's default thumbnail ratio when the wire omits one (AE4).
const double _defaultRatio = 358 / 221;

/// media: an image at an intrinsic aspect ratio. Images only — video ships in
/// the `neo_sdui_video` add-on; a video block without it renders its fallback.
Widget buildMedia(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  return AspectRatio(
    aspectRatio: _ratioOf(node),
    child: ClipRRect(
      borderRadius: theme.mediaRadius,
      child: Image.network(
        node.stringOr('url', '')!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : _placeholder(theme.shimmerBase, theme.shimmerHighlight),
        errorBuilder: (context, _, _) => _error(theme.shimmerBase),
      ),
    ),
  );
}

/// Explicit `ratio` wins; else raw `width`/`height`; else the default (R7, AE4).
double _ratioOf(BlockNode node) {
  final ratio = node.fields['ratio'];
  if (ratio is num && ratio > 0) return ratio.toDouble();
  final w = node.intOr('width'), h = node.intOr('height');
  if (w != null && h != null && h > 0) return w / h;
  return _defaultRatio;
}

// ponytail: static sheen skeleton; animate if real load times get long.
Widget _placeholder(Color base, Color highlight) => DecoratedBox(
      key: const Key('media-shimmer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [base, highlight, base]),
      ),
    );

Widget _error(Color base) =>
    ColoredBox(key: const Key('media-error'), color: base);
