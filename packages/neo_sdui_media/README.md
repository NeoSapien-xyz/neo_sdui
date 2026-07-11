# neo_sdui_media

A [`neo_sdui`](../neo_sdui) add-on: one `media` block that infers **image vs
video** from the URL and renders each — images cover-fit and aspect-locked,
videos looping/muted/autoplaying — with both disk-cached through a single
[`flutter_cache_manager`](https://pub.dev/packages/flutter_cache_manager).

## Install

```dart
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui_media/neo_sdui_media.dart';

final composition = NeoSdui.compose([neoSduiMediaAddon]);
// pass composition.registry + composition.capabilities to NeoSduiView.
```

Without the add-on, the core `media` block renders images only; a video URL
degrades to a placeholder box rather than crashing.

## Wire

```json
{ "type": "media", "url": "https://…/clip.mp4", "kind": "video", "ratio": 1.6 }
```

- `url` — image or video. Type is inferred from the extension
  (`.mp4`/`.mov`/`.webm`/`.m4v` → video); anything else is an image.
- `kind` — optional `image`/`video` override for extensionless or signed URLs.
- `ratio` / `width` / `height` — optional aspect ratio; otherwise a per-kind
  default.
