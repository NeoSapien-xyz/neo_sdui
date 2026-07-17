import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '_media_frame.dart';
import '_shape.dart';

/// how_to's default thumbnail ratio when the wire omits one (AE4).
const double _defaultRatio = 358 / 221;

/// media: an image at an intrinsic aspect ratio. Images only in core — the
/// `neo_sdui_media` add-on overrides this block to also infer and play video.
Widget buildMedia(BuildContext context, BlockNode node) {
  final theme = NeoSduiScope.of(context).theme;
  return AspectRatio(
    aspectRatio: node.ratioOr(_defaultRatio),
    child: clipShape(
      node.stringOr('shape'),
      theme.radiusMd,
      fallback: 'rounded',
      child: Image.network(
        node.stringOr('url', '')!,
        fit: BoxFit.cover,
        // Placeholder until the first frame, then one bounded fade-in (KTD9).
        frameBuilder: (context, child, frame, wasSync) {
          if (wasSync || theme.reduceMotion) return child;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (frame == null) neoImageShimmer(theme),
              AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: theme.motionDuration,
                curve: theme.motionCurve,
                child: child,
              ),
            ],
          );
        },
        errorBuilder: (context, _, _) => neoImageError(theme),
      ),
    ),
  );
}
