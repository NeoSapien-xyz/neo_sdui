import 'package:neo_sdui/neo_sdui.dart';

import 'syntax_code.dart';

/// The add-on. Compose via `NeoSdui.compose([neoSduiSyntaxAddon])`. It overrides
/// the core `code` block (last wins) and declares no capability — a core
/// override carries none (KTD1).
final NeoSduiAddon neoSduiSyntaxAddon = NeoSduiAddon(
  name: 'neo_sdui_syntax',
  blocks: {'code': buildSyntaxCode},
);
