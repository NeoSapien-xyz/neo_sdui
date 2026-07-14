import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// U6: the whole ledger→compile→lint pipeline over the MCP fixture (reversed
/// from `example/mcp_theme.dart`). Non-env-gated so it runs in plain
/// `flutter test`; the `compile_theme_test.dart` tool exercises the same fixture
/// end-to-end with the render preview.
void main() {
  test('MCP fixture reconciles, compiles, and lints clean', () {
    final json = jsonDecode(
            File('test/tools/testdata/theme_ledger_fixture.json')
                .readAsStringSync())
        as Map<String, Object?>;
    final reconciled = RoleLedger.fromJson(json).reconcile();

    // 15 roles from one page; no cross-page divergence -> no overrides.
    expect(reconciled.base, hasLength(15));
    expect(reconciled.base['accent']!.value, '0xFF00F1A0');
    expect(reconciled.overridesByPage, isEmpty);

    // Every wire role (tone:accent, emphasis:high, icon:download/sparkle)
    // resolves against the compiled theme.
    expect(lintRoleDrift(reconciled).where((i) => i.isBlocking), isEmpty);

    final src = emitTheme(reconciled);
    expect(src, contains('NeoSduiTheme.fallback().copyWith('));
    expect(src, contains('accent: Color(0xFF00F1A0),'));
    // inferred type/gradient roles carry the confirm marker.
    expect(src, contains('// confirm:'));

    // the live builder produces the fixture's palette.
    final theme = buildBaseTheme(reconciled);
    expect(theme.accent, const Color(0xFF00F1A0));
    expect(theme.surface, const Color(0xFF202423));
  });
}
