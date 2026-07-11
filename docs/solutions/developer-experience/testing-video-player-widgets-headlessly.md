---
title: Unit-testing video_player + flutter_cache_manager widgets headlessly in flutter_test
date: 2026-07-12
category: developer-experience
module: neo_sdui_media
problem_type: developer_experience
component: testing_framework
severity: high
applies_when:
  - Widget-testing a Flutter widget that drives video_player without a device or emulator
  - A widget resolves its source through flutter_cache_manager's getSingleFile
  - A widget-test hangs forever under pumpAndSettle
  - Assigning a CacheManager file into a dart:io File field fails to compile
  - Writing an async initialize/play/dispose lifecycle that must not leak on unmount
tags:
  - flutter
  - video-player
  - flutter-cache-manager
  - widget-test
  - platform-interface
  - mocktail
  - async-timing
related_components:
  - tooling
---

# Unit-testing video_player + flutter_cache_manager widgets headlessly in flutter_test

## Context

`neo_sdui_media` overrides the core `media` block to infer image-vs-video from a
URL and play video inline (loop, mute, autoplay), disk-caching both through one
`flutter_cache_manager`. The video path had to be covered by `flutter_test`
widget tests that run in CI with **no device, no emulator, and no real network
or disk** — the same headless gate the rest of `neo_sdui` runs under.

Three things fight you when you try this, and none of them are obvious from the
`video_player` or `flutter_cache_manager` READMEs:

1. `video_player` talks to a **platform channel**; with no platform registered,
   `initialize()` throws `MissingPluginException` and every video test is red.
2. `CacheManager.getSingleFile` returns a **`package:file` `File`**, not a
   `dart:io` `File` — so the naive `dart:io File f = await cache.getSingleFile(...)`
   does not compile, and the reverse assignment is a subtype trap.
3. A playing controller starts a `Timer.periodic` for position polling, so
   `tester.pumpAndSettle()` **never returns** — the test hangs until timeout.

This doc captures the harness that makes all three tractable, plus the
controller-lifecycle guard the harness exists to exercise.

**Prior art (session history).** The engine session two days earlier had already
met the shape of problem #3 on the core `media` block: it rejected an *animated*
shimmer specifically because "an endless animation never lets `pumpAndSettle`
settle" (and drains battery on an idle screen), and forbade unbounded motion
package-wide. Video's position timer is the same never-idle-ticker class — which
is why this harness pumps in fixed steps and unmounts, rather than settling.
That session also deferred video to a separate add-on precisely to keep core at
`flutter` + `meta` only, so `video_player` / `flutter_cache_manager` (and their
headless-testing burden) live here by design, not by accident.

## Guidance

### 1. Register a fake `VideoPlayerPlatform` — don't mock the controller

Do not try to mock `VideoPlayerController`. Swap the **platform interface**
underneath it, so the real controller runs its real lifecycle against an
in-memory fake. Extend `VideoPlayerPlatform` directly — its `super()` passes the
platform token, so you do **not** need `MockPlatformInterfaceMixin`:

```dart
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final List<String> calls = [];                       // lifecycle assertions
  final Map<int, StreamController<VideoEvent>> _events = {};
  int _next = 0;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    final controller = StreamController<VideoEvent>();  // NOT broadcast — buffers
    _events[id] = controller;
    controller.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 1),
      size: const Size(640, 360),                       // reports "ready" at 640x360
    ));
    calls.add('create');
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events[playerId]!.stream;

  @override
  Future<void> setLooping(int id, bool v) async => calls.add('setLooping:$v');
  @override
  Future<void> setVolume(int id, double v) async => calls.add('setVolume:$v');
  @override
  Future<void> play(int id) async => calls.add('play');
  @override
  Future<void> pause(int id) async => calls.add('pause');
  @override
  Future<void> dispose(int id) async {
    await _events.remove(id)?.close();
    calls.add('dispose');
  }
  // seekTo / getPosition / setPlaybackSpeed / setMixWithOthers -> trivial stubs
  @override
  Widget buildView(int id) => const SizedBox.shrink();
  @override
  Widget buildViewWithOptions(VideoViewOptions o) => const SizedBox.shrink();
}
```

Two details that cost iterations:

- The event `StreamController` **must not be a broadcast stream**. The controller
  subscribes *after* `createWithOptions` returns, and only a non-broadcast
  (buffered) controller replays the `initialized` event to that late subscriber.
  A broadcast stream drops it, `value.isInitialized` stays false forever, and the
  widget is stuck on the shimmer.
- Recording `calls` (`setLooping:true`, `setVolume:0.0`, `play`) is what lets you
  assert behavior — loop/mute/autoplay and reduce-motion — without a rendered
  frame.

Install it in `setUp`, after `TestWidgetsFlutterBinding.ensureInitialized()`:

```dart
VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform();
```

### 2. The cache manager is a swappable module-level seam, and it returns `package:file` File

`getSingleFile` returns a `package:file` `File`. Don't fight the type — import
`package:file` and build test assets with it. Wrap a **real** temp file so
`Image.file` / `VideoPlayerController.file` have real bytes to read:

```dart
import 'dart:io' as io;
import 'package:file/local.dart';

// setUpAll: write real bytes to a real path, then hand back a package:file File.
final path = '${io.Directory.systemTemp.path}/asset.png';
io.File(path).writeAsBytesSync(_pngBytes);           // a 1x1 transparent PNG
final asset = const LocalFileSystem().file(path);    // package:file File
```

Make the production cache manager a **mutable module-level variable** so tests
can swap it — a keyed `CacheManager`, never `DefaultCacheManager` (which is a
hard singleton you cannot displace):

```dart
// lib/src/media_cache.dart
BaseCacheManager mediaCacheManager = CacheManager(Config('neo_sdui_media'));
```

```dart
// test: swap in a mocktail fake in setUp
class _FakeCacheManager extends Mock implements BaseCacheManager {}
...
cache = _FakeCacheManager();
when(() => cache.getSingleFile(any())).thenAnswer((_) async => asset);
mediaCacheManager = cache;
```

Do **not** read the real `mediaCacheManager` at test-load time — its eager
`Config()` reaches for `path_provider` and throws `MissingPluginException`
before any test body runs. `setUp` overwrites it before the first widget builds,
so never touch the original.

### 3. Pump, never settle — and unmount to cancel the timer

A playing controller's `Timer.periodic` means `pumpAndSettle()` never completes.
Advance time in fixed steps instead:

```dart
Future<void> _settleVideo(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
```

End every video test by unmounting, so the timer is cancelled and the test
doesn't leak into the next one:

```dart
await tester.pumpWidget(const SizedBox()); // dispose -> cancels the timer
```

### 4. Failure paths must reject the Future asynchronously

Real `getSingleFile` rejects a Future on failure; it does not throw
synchronously. A synchronous `thenThrow` crashes inside `FutureBuilder`'s build
instead of degrading to the placeholder — the wrong code path. Model the real
one:

```dart
when(() => cache.getSingleFile(any()))
    .thenAnswer((_) async => throw Exception('boom'));   // async rejection
```

**Why a fake provider is not optional (session history).** On the core `media`
block the engine session tried to widget-test `reduceMotion` against a real
`Image.network` and had to delete the test as vacuous: headless, the network
image returns HTTP 400, so Flutter skips `frameBuilder` entirely and the
animation path is never exercised — "can't prove it without a network-image mock
dep." A network- or cache-backed media widget simply does not run its
load/animation branches headlessly. The fake `VideoPlayerPlatform` plus the
swapped `CacheManager` are what close that exact gap for the video path.

## Why This Matters

Without this harness the entire video branch is untestable in CI, which means
the loop/mute/autoplay contract, reduce-motion behavior, error degradation, and
the disk-cache routing all ship unverified. The harness makes the **real**
controller run its **real** lifecycle headlessly, so the tests exercise the
production code path rather than a mock of it.

It also exercises the controller-lifecycle guard that the async init demands.
Each `await` in `_load()` is a point where the widget can unmount (list scroll,
route pop, live wire change), and a controller created before an `await` that
never reaches `setState` is a leaked native player plus a running timer. The
guard: hold the controller in a local outside the `try`, `dispose` it in the
`catch`, and re-check `mounted` **after every await** — after `initialize()` and
again after `play()`:

```dart
Future<void> _load() async {
  VideoPlayerController? controller;             // outside try -> always disposable
  try {
    final file = await mediaCacheManager.getSingleFile(widget.url);
    if (!mounted) return;
    controller = VideoPlayerController.file(file);
    await controller.setLooping(widget.loop && !reduceMotion);
    await controller.setVolume(widget.mute ? 0 : 1);
    await controller.initialize();
    if (!mounted) { await controller.dispose(); return; }   // guard #1
    if (widget.autoplay && !reduceMotion) await controller.play();
    if (!mounted) { await controller.dispose(); return; }   // guard #2
    setState(() => _controller = controller);
  } catch (_) {
    await controller?.dispose();                 // throw after create still cleans up
    if (mounted) setState(() => _failed = true);
  }
}
```

Pair it with `didUpdateWidget`: when the element is reused at the same slot with
a new URL (common in server-driven UI), dispose the old controller and reload,
or the widget keeps playing the stale video.

## When to Apply

- Widget-testing any widget that drives `video_player` in `flutter_test`.
- Widget-testing any widget that resolves its source via
  `flutter_cache_manager.getSingleFile`.
- Any `StatefulWidget` whose `initState`/`_load` runs an async
  create/initialize/play sequence that must survive mid-await unmount.
- Any test that hangs under `pumpAndSettle` because the widget under test owns a
  periodic timer or an infinite animation.

## Examples

Behavioral assertions the harness unlocks, with no rendered frame:

```dart
// .mp4 plays looping + muted
await _pump(tester, _block(addonMedia, _media('clip.mp4')));
await _settleVideo(tester);
expect(platform.calls, contains('setLooping:true'));
expect(platform.calls, contains('setVolume:0.0'));
expect(platform.calls, contains('play'));
await tester.pumpWidget(const SizedBox());

// reduce-motion: no autoplay, no loop
final theme = NeoSduiTheme.fallback().copyWith(reduceMotion: true);
await _pump(tester, _block(addonMedia, _media('clip.mp4')), theme: theme);
await _settleVideo(tester);
expect(platform.calls, contains('setLooping:false'));
expect(platform.calls, isNot(contains('play')));

// failed load -> placeholder, no throw
when(() => cache.getSingleFile(any())).thenAnswer((_) async => throw Exception('x'));
await _pump(tester, _block(addonMedia, _media('gone.mp4')));
await _settleVideo(tester);
expect(find.byKey(const Key('media-error')), findsOneWidget);
expect(tester.takeException(), isNull);
```

## Related

- `packages/neo_sdui_media/test/media_addon_test.dart` — the full harness (fakes, `_settleVideo`, AE1-AE7).
- `packages/neo_sdui_media/lib/src/cached_video.dart` — the guarded async lifecycle.
- `packages/neo_sdui_media/lib/src/media_cache.dart` — the swappable module-level cache seam.
- [Server-driven UI: the wire carries semantics, the client owns the look](../architecture-patterns/sdui-look-is-client-owned.md) — the architecture this add-on plugs into.
