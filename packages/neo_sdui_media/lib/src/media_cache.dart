import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The single shared cache manager both media branches fetch through (R9,
/// KTD3). Keyed `neo_sdui_media` so it never shares (or corrupts) a host's own
/// `DefaultCacheManager` store. Typed as the interface and left mutable so a
/// test can swap in a fake — reset it back between tests.
BaseCacheManager mediaCacheManager = CacheManager(Config('neo_sdui_media'));
