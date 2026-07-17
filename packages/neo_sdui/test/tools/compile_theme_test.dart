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
/// `NeoSduiTheme` source and the coverage report, and runs two gates:
/// - the **guess gate** — FAILING if any role is `provenance:"inferred"`, i.e.
///   guessed off a screenshot instead of read from the design. Waive with
///   `NEO_THEME_ALLOW_INFERRED=1` (it ships the guesses; it is not a fix).
/// - the **role-drift lint** (`role_lint.dart`) — FAILING if a wire role names a
///   slot the compiled theme does not resolve.
///
/// Optionally writes the source to `NEO_THEME_OUT`. Set `NEO_THEME_BASE_PAGE` to
/// pin that page's look as the base (else majority wins — the R8 escape hatch).
/// Unset `NEO_THEME_LEDGER` (the default — e.g. plain `flutter test`), the test
/// is skipped so the suite stays green.
void main() {
  final ledgerPath = Platform.environment['NEO_THEME_LEDGER'];
  final outPath = Platform.environment['NEO_THEME_OUT'];
  final basePage = Platform.environment['NEO_THEME_BASE_PAGE'];
  final allowInferred = Platform.environment['NEO_THEME_ALLOW_INFERRED'] == '1';

  test('ledger compiles to a role-drift-clean theme', () {
    final json =
        jsonDecode(File(ledgerPath!).readAsStringSync()) as Map<String, Object?>;
    final ledger = RoleLedger.fromJson(json);
    if (ledger.malformedObservations > 0) {
      // ignore: avoid_print
      print('WARNING: dropped ${ledger.malformedObservations} malformed '
          'observation(s) from the ledger — the accumulated theme may be '
          'incomplete (corrupt/truncated write?), not just missing Figma data.');
    }
    final reconciled = ledger.reconcile(basePage: basePage);

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
    // The guess gate runs after every diagnostic has printed, and before the
    // drift lint: a theme built from screenshot reads is wrong in a way no
    // amount of clean drift redeems.
    final guessed = inferredRoleGate(reconciled, allow: allowInferred);
    expect(guessed, isNull, reason: guessed);

    final blocking = drift.where((i) => i.isBlocking).map((i) => i.toString());
    expect(
      blocking,
      isEmpty,
      reason: 'Wire roles with no theme slot — the theme would render them '
          'flat:\n${blocking.join('\n')}',
    );
  }, skip: ledgerPath == null);
}
