import 'package:flutter/foundation.dart';

import '../blocks/default_registry.dart';
import '../registry/block_registry.dart';
import 'neo_compose_report.dart';
import 'neo_sdui_addon.dart';

/// What `NeoSdui.compose` produces: the `{registry, capabilities}` a
/// `NeoSduiView` already takes, the never-throws diagnostics report, and the
/// add-ons' theme extensions collected in applied order (passthrough only).
@immutable
class NeoSduiComposition {
  const NeoSduiComposition({
    required this.registry,
    required this.capabilities,
    required this.report,
    this.themeExtensions = const [],
  });

  final BlockRegistry registry;
  final Map<String, int> capabilities;
  final NeoComposeReport report;
  final List<Object> themeExtensions;
}

/// Namespace for the add-on compose fold.
abstract final class NeoSdui {
  /// Fold [addons] (in order) onto [base] (the core roster when null), deriving
  /// the capability map from the same declarations that register the builders
  /// and collecting a never-throws diagnostics report. [capabilities] is an
  /// add-only host overlay. Never throws, for any input including `[]` (R12).
  static NeoSduiComposition compose(
    List<NeoSduiAddon> addons, {
    BlockRegistry? base,
    Map<String, int> capabilities = const {},
  }) {
    final coreBase = base ?? defaultRegistry();
    final registry = coreBase.copy();

    final owner = <String, String>{}; // add-on-registered type -> add-on name
    final typeCollisions = <NeoTypeCollision>[];
    final orphaned = <NeoOrphanedCapability>[];
    final derived = <String, int>{};
    final themeExtensions = <Object>[];
    final appliedOrder = <String>[];

    for (final addon in addons) {
      appliedOrder.add(addon.name);

      // Route each registered type: prior add-on owner -> collision (R9);
      // core-only -> silent override (R10); else brand-new. Last wins (R4).
      var registersNewType = false;
      for (final entry in addon.blocks.entries) {
        final type = entry.key;
        final prior = owner[type];
        if (prior != null) {
          typeCollisions.add(NeoTypeCollision(type, prior, addon.name));
        }
        if (!coreBase.contains(type)) {
          registersNewType = true;
        }
        registry.register(type, entry.value);
        owner[type] = addon.name;
      }

      // Caps enter only if the add-on backs them with a new type (R6, KTD4);
      // otherwise every declared cap is orphaned — reported and excluded (R9).
      for (final cap in addon.capabilities.entries) {
        if (registersNewType) {
          derived[cap.key] = cap.value; // last wins across add-ons, silent
        } else {
          orphaned.add(NeoOrphanedCapability(cap.key, addon.name));
        }
      }

      final ext = addon.themeExtension;
      if (ext != null) {
        themeExtensions.add(ext);
      }
    }

    // Add-only host overlay: a new key is added (R7); a derived key is kept and
    // the collision reported (R8).
    final overlayCollisions = <NeoOverlayCollision>[];
    final effective = Map<String, int>.of(derived);
    capabilities.forEach((key, value) {
      if (effective.containsKey(key)) {
        overlayCollisions.add(NeoOverlayCollision(key, effective[key]!, value));
      } else {
        effective[key] = value;
      }
    });

    final report = NeoComposeReport(
      typeCollisions: typeCollisions,
      orphanedCapabilities: orphaned,
      overlayCollisions: overlayCollisions,
      appliedOrder: appliedOrder,
    );

    // Debug channel: surface only the two real-problem classes (R11), never
    // throw (R12) — the closure runs in debug, is stripped in release, and
    // always returns true. Benign overlay collisions stay in the report only.
    assert(() {
      if (typeCollisions.isNotEmpty || orphaned.isNotEmpty) {
        debugPrint('NeoSdui.compose diagnostics:');
        for (final c in typeCollisions) {
          debugPrint('  $c');
        }
        for (final o in orphaned) {
          debugPrint('  $o');
        }
      }
      return true;
    }());

    return NeoSduiComposition(
      registry: registry,
      capabilities: effective,
      report: report,
      themeExtensions: themeExtensions,
    );
  }
}
