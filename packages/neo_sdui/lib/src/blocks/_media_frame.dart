import 'package:flutter/widgets.dart';

import '../theme/neo_sdui_theme.dart';

/// The guide's one inline-image loading idiom: reserve the [ratio] box up front
/// so the card never changes height, hold a shimmer skeleton while the asset
/// loads, then cross-fade the image in on its first frame (KTD9). A failed or
/// not-yet-published asset collapses to nothing — no empty ratio box — so a step
/// whose CDN image lags still reads as just its caption.
///
/// This is the fix for the "card expands when the image pops in" jump: the old
/// step image put its [AspectRatio] on the *loaded child only* and rendered a
/// zero-height `SizedBox.shrink` while pending, so the card mounted collapsed
/// and grew when the frame landed. Here the ratio box is reserved on the very
/// first (frame==null) `frameBuilder` call and never moves.
///
/// Look — the shimmer colors, the fade duration/curve, the corner [radius] — is
/// all theme roles; motion honors [NeoSduiTheme.reduceMotion]. Shared by every
/// content image that isn't a `media` block (the step thumbnails and the command
/// card's terminal shot) so they load identically to the hero. The `media` block
/// keeps its own shape-aware builder but draws the same [neoImageShimmer].
Widget neoNetworkImage(
  NeoSduiTheme theme,
  String url, {
  required double ratio,
  BorderRadius? radius,
  Alignment alignment = Alignment.center,
  Color? backdrop,
}) {
  final image = Image.network(
    url,
    fit: BoxFit.cover,
    alignment: alignment,
    // A broken/unpublished asset leaves no gap — collapse rather than reserve an
    // empty box. (Error replaces the frameBuilder output, so no AspectRatio.)
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
    frameBuilder: (_, child, frame, wasSync) {
      final content = (wasSync || theme.reduceMotion)
          ? child
          : Stack(
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
      // Reserved on the first (frame==null) call, so the card holds this height
      // through the whole load — no expand-on-arrival.
      return AspectRatio(
        aspectRatio: ratio,
        child: backdrop == null ? content : ColoredBox(color: backdrop, child: content),
      );
    },
  );
  return radius == null ? image : ClipRRect(borderRadius: radius, child: image);
}

// ponytail: static sheen skeleton; animate if real load times get long.
/// Loading skeleton — a static gradient sheen. One definition for the whole core
/// package (the `media` block and [neoNetworkImage]); the add-on mirrors it as
/// `mediaShimmer` across the package boundary.
Widget neoImageShimmer(NeoSduiTheme theme) => DecoratedBox(
      key: const Key('media-shimmer'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.shimmerBase, theme.shimmerHighlight, theme.shimmerBase],
        ),
      ),
    );

/// Degrade box — a flat fill for a failed load where the box is kept reserved
/// (the `media` block always holds its ratio). Never a raw error (R6).
Widget neoImageError(NeoSduiTheme theme) =>
    ColoredBox(key: const Key('media-error'), color: theme.shimmerBase);
