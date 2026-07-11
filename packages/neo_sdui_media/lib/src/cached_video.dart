import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:video_player/video_player.dart';

import 'media_cache.dart';
import 'media_states.dart';

/// Builds the controller from a resolved cache [File]. The default uses the
/// real `.file` constructor; tests inject a fake (or register a
/// `FakeVideoPlayerPlatform`) so the lifecycle runs without a device (KTD6).
typedef VideoControllerFactory = VideoPlayerController Function(File file);

VideoPlayerController _defaultFactory(File file) =>
    VideoPlayerController.file(file);

/// Plays a video from the shared disk cache, mirroring neo's how_to: looping,
/// muted, autoplaying, no controls. A shimmer shows while loading and a
/// placeholder box on failure — never a raw error (R6). The [ratio] box is
/// fixed for every state (shimmer, ready, error) and the video cover-fills it,
/// so nothing resizes when the controller initializes (R4, R7, R8, KTD6/KTD7).
/// When the theme requests reduced motion, the video initializes to a static
/// first frame instead of autoplaying/looping (R8).
class CachedVideo extends StatefulWidget {
  const CachedVideo({
    super.key,
    required this.url,
    required this.ratio,
    this.loop = true,
    this.mute = true,
    this.autoplay = true,
    this.controllerFactory = _defaultFactory,
  });

  final String url;
  final double ratio;
  final bool loop;
  final bool mute;
  final bool autoplay;
  final VideoControllerFactory controllerFactory;

  @override
  State<CachedVideo> createState() => _CachedVideoState();
}

class _CachedVideoState extends State<CachedVideo> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final file = await mediaCacheManager.getSingleFile(widget.url);
      if (!mounted) return;
      final reduceMotion = NeoSduiScope.of(context).theme.reduceMotion;
      final controller = widget.controllerFactory(file);
      await controller.setLooping(widget.loop && !reduceMotion);
      await controller.setVolume(widget.mute ? 0 : 1);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (widget.autoplay && !reduceMotion) {
        await controller.play();
      }
      setState(() => _controller = controller);
    } catch (_) {
      // Any resolve/init failure degrades to the placeholder — never a throw.
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NeoSduiScope.of(context).theme;
    final controller = _controller;

    final Widget child;
    if (_failed) {
      child = mediaPlaceholder(theme);
    } else if (controller != null && controller.value.isInitialized) {
      // Cover-fill the fixed ratio box; do not adopt the controller's ratio.
      child = FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      );
    } else {
      child = mediaShimmer(theme);
    }

    return AspectRatio(
      aspectRatio: widget.ratio,
      child: ClipRRect(borderRadius: theme.radiusMd, child: child),
    );
  }
}
