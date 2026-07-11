import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// Loading skeleton — a static gradient sheen, mirroring core `media`'s
/// placeholder. Shared by the image and video branches so both loading states
/// look identical (R6, R8).
Widget mediaShimmer(NeoSduiTheme theme) => DecoratedBox(
      key: const Key('media-shimmer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.shimmerBase, theme.shimmerHighlight, theme.shimmerBase],
        ),
      ),
    );

/// Degrade box — a flat fill shown on a failed load, matching core `media`'s
/// error box. Never a raw error or a thrown exception (R6).
Widget mediaPlaceholder(NeoSduiTheme theme) =>
    ColoredBox(key: const Key('media-error'), color: theme.shimmerBase);
