import '../registry/block_registry.dart';
import 'callout.dart';
import 'card.dart';
import 'cta.dart';
import 'faq.dart';
import 'header.dart';
import 'media.dart';
import 'steps.dart';
import 'tabs.dart';
import 'text.dart';

/// The core roster, seeded into a fresh registry. Add-ons `copy()` then
/// `register()` their own types on top.
BlockRegistry defaultRegistry() => BlockRegistry.empty()
  ..register('header', buildHeader)
  ..register('text', buildText)
  ..register('cta', buildCta)
  ..register('callout', buildCallout)
  ..register('media', buildMedia)
  ..register('card', buildCard)
  ..register('steps', buildSteps)
  ..register('faq', buildFaq)
  ..register('tabs', buildTabs);
