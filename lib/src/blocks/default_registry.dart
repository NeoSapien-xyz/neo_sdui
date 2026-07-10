import '../registry/block_registry.dart';
import 'callout.dart';
import 'cta.dart';
import 'header.dart';
import 'media.dart';
import 'text.dart';

/// The core roster, seeded into a fresh registry. Add-ons `copy()` then
/// `register()` their own types on top.
BlockRegistry defaultRegistry() => BlockRegistry.empty()
  ..register('header', buildHeader)
  ..register('text', buildText)
  ..register('cta', buildCta)
  ..register('callout', buildCallout)
  ..register('media', buildMedia);
