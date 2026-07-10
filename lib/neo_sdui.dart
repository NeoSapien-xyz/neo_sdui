/// neo_sdui — a pure-Dart engine that renders one Remote Config JSON document
/// per guide into baked, themed Flutter widgets.
///
/// The wire carries semantic block types and token names; the client owns all
/// styling (passed via the renderer constructor). One document model and one
/// block registry serve every guide.
library;

// Model
export 'src/model/block_node.dart';
export 'src/model/document.dart';
export 'src/model/validation.dart';
export 'src/model/view.dart';

// Registry
export 'src/registry/block_registry.dart';

// Actions
export 'src/action/neo_action.dart';

// Theme
export 'src/theme/neo_sdui_scope.dart';
export 'src/theme/neo_sdui_theme.dart';
