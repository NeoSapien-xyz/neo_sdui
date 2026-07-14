import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// Theme-compile entrypoint for the `figwire` skill.
///
/// Set `NEO_THEME_LEDGER` to a role-ledger `.json` path and run:
///
///   flutter test test/tools/compile_theme_test.dart
///
/// It reconciles the ledger (batch, order-independent), prints the paste-in
/// `NeoSduiTheme` source and the coverage report, and runs the role-drift lint
/// (`role_lint.dart`) — FAILING if a wire role names a slot the compiled theme
/// does not resolve. Optionally writes the source to `NEO_THEME_OUT`. Unset (the
/// default — e.g. plain `flutter test`), the test is skipped so the suite stays
/// green.
void main() {
  final ledgerPath = Platform.environment['NEO_THEME_LEDGER'];
  final outPath = Platform.environment['NEO_THEME_OUT'];

  test('ledger compiles to a role-drift-clean theme', () {
    final json =
        jsonDecode(File(ledgerPath!).readAsStringSync()) as Map<String, Object?>;
    final ledger = RoleLedger.fromJson(json);
    final reconciled = ledger.reconcile();

    final source = emitTheme(reconciled);
    // ignore: avoid_print
    print(source);
    // ignore: avoid_print
    print(coverageReport(reconciled));

    if (outPath != null) {
      File(outPath).writeAsStringSync(source);
      // ignore: avoid_print
      print('Wrote theme to $outPath');
    }

    final drift = lintRoleDrift(reconciled);
    for (final i in drift) {
      // ignore: avoid_print
      print('ROLE $i');
    }
    final blocking = drift.where((i) => i.isBlocking).map((i) => i.toString());
    expect(
      blocking,
      isEmpty,
      reason: 'Wire roles with no theme slot — the theme would render them '
          'flat:\n${blocking.join('\n')}',
    );
  }, skip: ledgerPath == null);
}
