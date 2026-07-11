import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui_media/neo_sdui_media.dart';
import 'package:neo_sdui_media/src/cached_image.dart';
import 'package:neo_sdui_media/src/cached_video.dart';
import 'package:neo_sdui_media/src/media_cache.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

// --- Fakes -------------------------------------------------------------------

class _FakeCacheManager extends Mock implements BaseCacheManager {}

/// A headless video platform: records lifecycle calls and reports every player
/// as initialized at 640x360, so the real `VideoPlayerController` runs without
/// a device. Extends the interface directly (super() passes the platform token).
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = [];
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _next = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    final controller = StreamController<VideoEvent>();
    _events[id] = controller;
    controller.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 1),
      size: const Size(640, 360),
    ));
    calls.add('create');
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('setLooping:$looping');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('setVolume:$volume');

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
    calls.add('dispose');
  }

  @override
  Widget buildView(int playerId) => const SizedBox.shrink();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.shrink();
}

// --- Helpers -----------------------------------------------------------------

/// A 1x1 transparent PNG, so `Image.file` has a real file to point at.
final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
);

BlockNode _media(String url, {String? kind, Map<String, Object?> extra = const {}}) =>
    BlockNode(type: 'media', fields: {'url': url, 'kind': ?kind, ...extra});

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  NeoSduiTheme? theme,
}) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 320,
            height: 320,
            child: NeoSduiScope(
              theme: theme ?? NeoSduiTheme.fallback(),
              dispatch: (_, _) {},
              buildBlocks: (_) => const [],
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Renders a block node through a registry's builder (as `NeoSduiView` would).
Widget _block(BlockBuilder builder, BlockNode node) =>
    Builder(builder: (context) => builder(context, node));

/// Advances async gaps + timers without `pumpAndSettle` (the video position
/// timer never settles).
Future<void> _settleVideo(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final withAddon = NeoSdui.compose([neoSduiMediaAddon]).registry;
  final coreOnly = NeoSdui.compose(const []).registry;
  final addonMedia = withAddon.builderFor('media')!;
  final coreMedia = coreOnly.builderFor('media')!;

  // Never read the real (path_provider-backed) mediaCacheManager — setUp swaps
  // in the fake before any widget builds.
  late _FakeCacheManager cache;
  late _FakeVideoPlayerPlatform platform;
  late File asset;

  setUpAll(() {
    // getSingleFile returns a package:file File (a dart:io File subtype), so
    // wrap a real temp path we write the bytes to.
    final path = '${io.Directory.systemTemp.path}/neo_sdui_media_test.png';
    io.File(path).writeAsBytesSync(_pngBytes);
    asset = const LocalFileSystem().file(path);
  });

  setUp(() {
    cache = _FakeCacheManager();
    when(() => cache.getSingleFile(any())).thenAnswer((_) async => asset);
    mediaCacheManager = cache;
    platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });


  group('add-on present', () {
    testWidgets('AE1: .mp4 plays looping + muted', (tester) async {
      await _pump(tester, _block(addonMedia, _media('clip.mp4')));
      await _settleVideo(tester);

      expect(find.byType(CachedVideo), findsOneWidget);
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.calls, contains('setLooping:true'));
      expect(platform.calls, contains('setVolume:0.0'));
      expect(platform.calls, contains('play'));

      await tester.pumpWidget(const SizedBox()); // dispose -> cancel timer
    });

    testWidgets('AE2: .png renders cover-fit, aspect-locked', (tester) async {
      await _pump(tester, _block(addonMedia, _media('pic.png', extra: {'ratio': 1.6})));
      await tester.pump();

      expect(find.byType(CachedImage), findsOneWidget);
      final aspect = tester.widget<AspectRatio>(
        find.descendant(of: find.byType(CachedImage), matching: find.byType(AspectRatio)),
      );
      expect(aspect.aspectRatio, 1.6);
      expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    });

    testWidgets('AE3: extensionless + kind:video routes to video', (tester) async {
      await _pump(tester, _block(addonMedia, _media('opaque', kind: 'video')));
      await _settleVideo(tester);

      expect(find.byType(CachedVideo), findsOneWidget);
      expect(find.byType(CachedImage), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('AE4: failed load -> placeholder, no throw', (tester) async {
      // Reject the Future (async) as the real getSingleFile would — not a
      // synchronous throw.
      when(() => cache.getSingleFile(any()))
          .thenAnswer((_) async => throw Exception('boom'));

      await _pump(tester, _block(addonMedia, _media('gone.mp4')));
      await _settleVideo(tester);
      expect(find.byKey(const Key('media-error')), findsOneWidget);

      await _pump(tester, _block(addonMedia, _media('gone.png')));
      await tester.pump();
      expect(find.byKey(const Key('media-error')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('AE5: both branches route through the one cache manager',
        (tester) async {
      await _pump(tester, _block(addonMedia, _media('pic.png')));
      await tester.pump();
      verify(() => cache.getSingleFile('pic.png')).called(1);

      await _pump(tester, _block(addonMedia, _media('clip.mp4')));
      await _settleVideo(tester);
      verify(() => cache.getSingleFile('clip.mp4')).called(1);
      // Disk dedup on a repeat view is flutter_cache_manager's own contract
      // (getSingleFile returns the cached file when valid); we verify only that
      // both branches go through the single shared manager (R9).

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduce-motion: no autoplay, no loop', (tester) async {
      final theme = NeoSduiTheme.fallback().copyWith(reduceMotion: true);
      await _pump(tester, _block(addonMedia, _media('clip.mp4')), theme: theme);
      await _settleVideo(tester);

      expect(platform.calls, contains('setLooping:false'));
      expect(platform.calls, isNot(contains('play')));

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('video reloads on a live url change (didUpdateWidget)',
        (tester) async {
      await _pump(tester, _block(addonMedia, _media('first.mp4')));
      await _settleVideo(tester);
      verify(() => cache.getSingleFile('first.mp4')).called(1);

      // Same widget slot, new url -> element reused -> didUpdateWidget reloads.
      await _pump(tester, _block(addonMedia, _media('second.mp4')));
      await _settleVideo(tester);
      verify(() => cache.getSingleFile('second.mp4')).called(1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('empty url collapses to nothing', (tester) async {
      await _pump(tester, _block(addonMedia, _media('')));
      await tester.pump();

      expect(find.byType(CachedImage), findsNothing);
      expect(find.byType(CachedVideo), findsNothing);
    });

    testWidgets('debug guard warns on extensionless, kind-less url',
        (tester) async {
      final logs = <String>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');

      await _pump(tester, _block(addonMedia, _media('opaque-no-ext')));
      await tester.pump();

      debugPrint = original;
      expect(logs.any((l) => l.contains('inferred image')), isTrue);
      expect(find.byType(CachedImage), findsOneWidget);
    });
  });

  group('add-on absent (degrade)', () {
    testWidgets('AE7: .png renders via core image, no crash', (tester) async {
      await _pump(tester, _block(coreMedia, _media('pic.png')));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget); // core Image.network
      tester.takeException(); // swallow the deterministic network-image error
    });

    testWidgets('AE6: .mp4 shows core placeholder, no crash', (tester) async {
      await _pump(tester, _block(coreMedia, _media('clip.mp4')));
      await tester.pump();

      // core treats it as an image url (Image.network) — no video, no crash.
      expect(find.byType(CachedVideo), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      tester.takeException(); // swallow the deterministic network-image error
    });
  });
}
