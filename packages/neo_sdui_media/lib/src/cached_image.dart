import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

import 'media_cache.dart';
import 'media_states.dart';

/// Renders an image from the shared disk cache, matching core `media`'s look —
/// aspect-locked, cover-fit, rounded, with a shimmer while loading, a bounded
/// fade-in on first frame, and a placeholder box on failure — but sourcing a
/// cached `File` instead of the network (R5, R6, R8, R9).
class CachedImage extends StatelessWidget {
  const CachedImage({super.key, required this.url, required this.ratio});

  final String url;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: theme.radiusMd,
        child: FutureBuilder<File>(
          future: mediaCacheManager.getSingleFile(url),
          builder: (context, snapshot) {
            if (snapshot.hasError) return mediaPlaceholder(theme);
            final file = snapshot.data;
            if (file == null) return mediaShimmer(theme);
            return Image.file(
              file,
              fit: BoxFit.cover,
              // Placeholder until the first frame, then one bounded fade-in —
              // mirrors core media (KTD7).
              frameBuilder: (context, child, frame, wasSync) {
                if (wasSync || theme.reduceMotion) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (frame == null) mediaShimmer(theme),
                    AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: theme.motionDuration,
                      curve: theme.motionCurve,
                      child: child,
                    ),
                  ],
                );
              },
              errorBuilder: (context, _, _) => mediaPlaceholder(theme),
            );
          },
        ),
      ),
    );
  }
}
