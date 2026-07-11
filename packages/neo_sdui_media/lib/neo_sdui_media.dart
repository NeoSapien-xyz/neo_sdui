/// neo_sdui_media — an add-on that overrides the core `media` block with a
/// builder inferring image vs video from the URL, rendering each accordingly,
/// and disk-caching both through one `flutter_cache_manager`.
///
/// Install: `NeoSdui.compose([neoSduiMediaAddon])`.
library;

// Builders stay registry-only (core convention) — expose just the add-on.
export 'src/media_addon.dart' hide buildMediaBlock;
