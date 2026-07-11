import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/how_to/how_to_document.dart';

void main() {
  final map = jsonDecode(howToDocumentJson) as Map<String, Object?>;
  final doc = NeoDocument.fromJson(map);

  test('the how_to document validates with zero issues', () {
    expect(validateDocument(map), isEmpty);
  });

  test('index is a header + three topic cards', () {
    expect(doc.blocks.map((b) => b.type).toList(),
        ['header', 'card', 'card', 'card']);
  });

  test('every card sheet: action resolves to a sheet view', () {
    final cards = doc.blocks.where((b) => b.type == 'card');
    expect(cards, hasLength(3));
    for (final card in cards) {
      final action = NeoAction.parse(card.stringOr('action', '')!);
      expect(action, isA<OpenView>());
      final open = action as OpenView;
      expect(open.present, NeoViewPresent.sheet);
      final view = doc.viewById(open.id);
      expect(view, isNotNull, reason: 'card points at missing view ${open.id}');
      expect(view!.present, NeoViewPresent.sheet);
    }
  });

  test('each sheet ends in a Got it cta that closes the sheet', () {
    for (final view in doc.views.values) {
      final cta = view.blocks.lastWhere((b) => b.type == 'cta');
      expect(NeoAction.parse(cta.stringOr('action', '')!), isA<CloseView>());
    }
  });
}
