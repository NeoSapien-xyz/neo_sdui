import 'package:meta/meta.dart';

/// Two add-ons claimed the same block `type`; [winner] (last in list) won,
/// [loser] was clobbered (R9). Core overrides are not reported (R10).
@immutable
class NeoTypeCollision {
  const NeoTypeCollision(this.type, this.loser, this.winner);

  final String type;
  final String loser;
  final String winner;

  @override
  String toString() =>
      "type '$type': $winner overrode $loser (last-in-list wins)";
}

/// An add-on declared [capability] but registered no new block type to back it,
/// so it never entered the effective map (R9).
@immutable
class NeoOrphanedCapability {
  const NeoOrphanedCapability(this.capability, this.addon);

  final String capability;
  final String addon;

  @override
  String toString() =>
      "capability '$capability' from $addon has no new-type builder";
}

/// A host overlay named [capability] already derived from an add-on; the
/// derived [kept] version stayed and the overlay's [ignored] version was dropped
/// (R8).
@immutable
class NeoOverlayCollision {
  const NeoOverlayCollision(this.capability, this.kept, this.ignored);

  final String capability;
  final int kept;
  final int ignored;

  @override
  String toString() =>
      "overlay '$capability': kept derived $kept, ignored overlay $ignored";
}

/// The never-throws diagnostics `NeoSdui.compose` returns (R9, R12). Catalogs
/// the three problem categories plus the final applied order.
@immutable
class NeoComposeReport {
  const NeoComposeReport({
    this.typeCollisions = const [],
    this.orphanedCapabilities = const [],
    this.overlayCollisions = const [],
    this.appliedOrder = const [],
  });

  final List<NeoTypeCollision> typeCollisions;
  final List<NeoOrphanedCapability> orphanedCapabilities;
  final List<NeoOverlayCollision> overlayCollisions;

  /// Add-on names in the order compose applied them.
  final List<String> appliedOrder;

  /// No collisions and no orphans.
  bool get isClean =>
      typeCollisions.isEmpty &&
      orphanedCapabilities.isEmpty &&
      overlayCollisions.isEmpty;

  @override
  String toString() {
    final lines = [
      for (final c in typeCollisions) '  $c',
      for (final o in orphanedCapabilities) '  $o',
      for (final o in overlayCollisions) '  $o',
    ];
    return 'NeoComposeReport(order: ${appliedOrder.join(' -> ')})'
        '${lines.isEmpty ? ' clean' : '\n${lines.join('\n')}'}';
  }
}
