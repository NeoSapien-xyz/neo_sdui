import 'package:meta/meta.dart';

import '../registry/block_registry.dart';

/// One add-on, bundled: the block types it registers, the capabilities it
/// provides, and an optional theme extension. `NeoSdui.compose` folds a list of
/// these into the `{registry, capabilities}` a `NeoSduiView` already takes, so
/// registering a block and declaring its capability are one declaration and
/// can't drift (R1).
@immutable
class NeoSduiAddon {
  const NeoSduiAddon({
    required this.name,
    this.blocks = const {},
    this.capabilities = const {},
    this.themeExtension,
  });

  /// Human name, used only to attribute collisions/orphans in the report (R9).
  final String name;

  /// Wire `type` -> builder this add-on contributes.
  final Map<String, BlockBuilder> blocks;

  /// Feature -> supported major version this add-on provides. May be empty —
  /// e.g. an add-on that only replaces a core block (R2).
  final Map<String, int> capabilities;

  /// Passthrough only; the theme-merge mechanics live in a separate brainstorm.
  final Object? themeExtension;
}
