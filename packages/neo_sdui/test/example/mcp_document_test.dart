import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

import '../../example/mcp/mcp_document.dart';

void main() {
  final map = jsonDecode(mcpDocumentJson) as Map<String, Object?>;
  final doc = NeoDocument.fromJson(map);

  test('the MCP document validates with zero issues', () {
    expect(validateDocument(map), isEmpty);
  });

  test('declares the five per-guide views', () {
    expect(doc.views.keys.toSet(),
        {'chatgpt', 'claude', 'other', 'faq', 'troubleshooting'});
    for (final v in doc.views.values) {
      expect(v.present, NeoViewPresent.screen);
    }
  });

  test('every screen:/sheet: action across the whole doc resolves to a view', () {
    final opens = _collectOpenViews(map);
    // intro picker (3) + intro footer (2) + a footer pair in each of the three
    // client views (6) = 11 view actions in total.
    expect(opens, hasLength(11));
    for (final open in opens) {
      final view = doc.viewById(open.id);
      expect(view, isNotNull, reason: 'action points at missing view ${open.id}');
      expect(view!.present, open.present);
    }
  });

  test('the client-picker cards open their screen views', () {
    final cards = doc.blocks.where((b) => b.type == 'card');
    final picks = {
      for (final c in cards)
        if (c.stringOr('action')?.startsWith('screen:') ?? false)
          c.stringOr('title'): c.stringOr('action'),
    };
    expect(picks['ChatGPT'], 'screen:chatgpt');
    expect(picks['Claude'], 'screen:claude');
    expect(picks['Others'], 'screen:other');
    for (final action in picks.values) {
      final open = NeoAction.parse(action!) as OpenView;
      expect(doc.viewById(open.id), isNotNull);
    }
  });

  test('the faq view holds all seven Q/A pairs', () {
    final faqView = doc.viewById('faq')!;
    final faqBlock = faqView.blocks.firstWhere((b) => b.type == 'faq');
    final items = faqBlock.mapList('items');
    expect(items, hasLength(7));
    for (final item in items) {
      expect(item['question'], isA<String>());
      expect(item['answer'], isA<String>());
    }
  });

  test('the troubleshooting view ends in an external Contact Support cta', () {
    final view = doc.viewById('troubleshooting')!;
    final cta = view.blocks.lastWhere((b) => b.type == 'cta');
    expect(cta.stringOr('label'), 'Contact Support');
    expect(NeoAction.parse(cta.stringOr('action', '')!), isA<ExternalUrl>());
    // Five troubleshooting items rendered as callouts.
    expect(view.blocks.where((b) => b.type == 'callout'), hasLength(5));
  });
}

/// Every `screen:`/`sheet:` action anywhere in the decoded document (root blocks,
/// view blocks, and nested tab blocks) — found by walking every `action` string.
List<OpenView> _collectOpenViews(Object? node) {
  final out = <OpenView>[];
  void walk(Object? n) {
    if (n is Map) {
      final action = n['action'];
      if (action is String) {
        final parsed = NeoAction.parse(action);
        if (parsed is OpenView) out.add(parsed);
      }
      n.values.forEach(walk);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return out;
}
