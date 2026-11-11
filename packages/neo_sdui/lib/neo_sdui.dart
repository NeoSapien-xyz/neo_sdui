/// neo_sdui — renders one Remote Config JSON document per guide into baked,
/// themed Flutter widgets. Wire names block types; the app owns styling.
library;

// Model
export 'src/model/block_node.dart';
export 'src/model/document.dart';
export 'src/model/validate_vocabulary.dart';
export 'src/model/validation.dart';
export 'src/model/view.dart';

// Registry
export 'src/blocks/default_registry.dart';
export 'src/registry/block_registry.dart';

// Compose
export 'src/compose/neo_compose.dart';
export 'src/compose/neo_compose_report.dart';
export 'src/compose/neo_sdui_addon.dart';

// Actions
export 'src/action/neo_action.dart';

// Theme
export 'src/theme/neo_css_angle.dart';
export 'src/theme/neo_sdui_scope.dart';
export 'src/theme/neo_sdui_styles.dart';
export 'src/theme/neo_sdui_theme.dart';

// Authoring (figwire theme-companion: ledger → compile → lint)
export 'src/authoring/theme_ledger.dart';
export 'src/authoring/theme_compile.dart';
export 'src/authoring/role_lint.dart';

// Renderer
export 'src/render/neo_sdui_view.dart';
