import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

/// Validation entrypoint for the `figwire` skill.
///
/// Set `NEO_WIRE_JSON` to a wire `.json` path and run:
///
///   flutter test test/tools/check_wire_test.dart
///
/// It prints every structural (`validateDocument`) and vocabulary
/// (`validateWireVocabulary`) issue, and FAILS if any is blocking — a structural
/// error, an off-roster `type`, or a non-map block — so the skill refuses to
/// write the document. Warnings (missing required fields) print but do not fail.
/// Unset (the default), the test is skipped so the suite stays green.
void main() {
  final wirePath = Platform.environment['NEO_WIRE_JSON'];

  test('wire JSON is structurally sound and on-vocabulary', () {
    final map =
        jsonDecode(File(wirePath!).readAsStringSync()) as Map<String, Object?>;

    final structural = validateDocument(map);
    final vocab = validateWireVocabulary(map);

    for (final i in structural) {
      // ignore: avoid_print
      print('STRUCT $i');
    }
    for (final i in vocab) {
      // ignore: avoid_print
      print('VOCAB  $i');
    }

    final blocking = <String>[
      ...structural.map((i) => i.toString()),
      ...vocab.where((i) => i.isBlocking).map((i) => i.toString()),
    ];
    expect(
      blocking,
      isEmpty,
      reason: 'Blocking issues — do not write this document:\n'
          '${blocking.join('\n')}',
    );
  }, skip: wirePath == null);
}
