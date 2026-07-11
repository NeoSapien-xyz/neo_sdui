import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';

import 'cached_image.dart';
import 'cached_video.dart';
import 'media_kind.dart';

const double _imageRatio = 358 / 221;
const double _videoRatio = 16 / 9;

/// The add-on's `media` builder: collapses a blank block, infers image vs
/// video, resolves a fixed aspect ratio, and routes to the cached image or
/// video branch. Inline and Navigator-free; reads only semantic wire fields
/// (R1, R2, R3, R7, R13, R14).
Widget buildMediaBlock(BuildContext context, BlockNode node) {
  final url = node.stringOr('url', '')!;
  // A media block authored with no url collapses rather than reserving a box.
  if (url.isEmpty) return const SizedBox.shrink();

  final kind = node.stringOr('kind');

  // Debug guard: a video authored with no recognized extension and no `kind`
  // silently infers as image — surface it loudly in debug (stripped in
  // release; never throws, R13).
  assert(() {
    if (kind == null && !hasRecognizedExtension(url)) {
      debugPrint(
        'neo_sdui_media: "$url" has no recognized extension and no kind — '
        'inferred image. Add kind:video if this is a video.',
      );
    }
    return true;
  }());

  if (inferMediaKind(url, kind: kind) == MediaKind.video) {
    return CachedVideo(
      url: url,
      ratio: _ratioOf(node, _videoRatio),
      loop: node.boolOr('loop', or: true),
      mute: node.boolOr('mute', or: true),
      autoplay: node.boolOr('autoplay', or: true),
    );
  }
  return CachedImage(url: url, ratio: _ratioOf(node, _imageRatio));
}

/// Explicit `ratio` wins; else raw `width`/`height`; else [fallback] — mirrors
/// core `media`'s `_ratioOf`, with a per-kind fallback (R7).
double _ratioOf(BlockNode node, double fallback) {
  final ratio = node.fields['ratio'];
  if (ratio is num && ratio > 0) return ratio.toDouble();
  final w = node.intOr('width'), h = node.intOr('height');
  if (w != null && h != null && h > 0) return w / h;
  return fallback;
}

/// The add-on. Compose it via `NeoSdui.compose([neoSduiMediaAddon])`. It
/// overrides the core `media` block and declares no capability — a core
/// override carries none (KTD1).
final NeoSduiAddon neoSduiMediaAddon = NeoSduiAddon(
  name: 'neo_sdui_media',
  blocks: {'media': buildMediaBlock},
);
