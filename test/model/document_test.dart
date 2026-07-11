import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

void main() {
  group('NeoDocument.fromJson', () {
    test('parses blocks and views into a typed model', () {
      final doc = NeoDocument.fromJson({
        'version': 1,
        'blocks': [
          {'type': 'header', 'title': 'How to use your Neo 1'},
          {'type': 'card', 'title': 'How can I control Neo 1?', 'action': 'sheet:control'},
        ],
        'views': {
          'control': {
            'present': 'sheet',
            'blocks': [
              {'type': 'text', 'body': 'Neo 1 responds to touch and voice.'},
            ],
          },
          'chatgpt': {
            'present': 'screen',
            'blocks': [
              {'type': 'header', 'title': 'ChatGPT MCP'},
            ],
          },
        },
      });

      expect(doc.version, 1);
      expect(doc.blocks, hasLength(2));
      expect(doc.blocks.first.type, 'header');
      expect(doc.blocks.first.stringOr('title'), 'How to use your Neo 1');
      expect(doc.blocks[1].stringOr('action'), 'sheet:control');
      expect(doc.viewById('control')!.present, NeoViewPresent.sheet);
      expect(doc.viewById('chatgpt')!.present, NeoViewPresent.screen);
      expect(doc.viewById('control')!.blocks.single.type, 'text');
    });

    test('missing/non-string type parses to the invalid sentinel', () {
      final node = BlockNode.fromJson({'title': 'no type here'});
      expect(node.type, BlockNode.invalidType);
      expect(node.isValidType, isFalse);
    });

    test('requires and fallback parse off the envelope', () {
      final node = BlockNode.fromJson({
        'type': 'videoCard',
        'url': 'https://cdn.neo/clip.mp4',
        'requires': {'video': '1.2'},
        'fallback': {'type': 'cta', 'label': 'Watch on web', 'action': 'https://neo/clip'},
      });
      expect(node.requires, {'video': '1.2'});
      expect(node.fallback!.type, 'cta');
      expect(node.fallback!.stringOr('label'), 'Watch on web');
      // Envelope keys are stripped from fields.
      expect(node.fields.containsKey('requires'), isFalse);
      expect(node.fields.containsKey('fallback'), isFalse);
      expect(node.stringOr('url'), 'https://cdn.neo/clip.mp4');
    });

    test('absent field falls back to the caller default (R4)', () {
      final node = BlockNode.fromJson({'type': 'media', 'src': 'x'});
      expect(node.intOr('width', 1600), 1600);
      expect(node.stringOr('missing', 'def'), 'def');
    });
  });

  group('validateDocument', () {
    test('a well-formed document has no issues', () {
      final issues = validateDocument({
        'version': 1,
        'blocks': [
          {'type': 'header', 'title': 'x'},
        ],
        'views': {
          'a': {'present': 'screen', 'blocks': []},
        },
      });
      expect(issues, isEmpty);
    });

    test('collects every problem instead of throwing on the first', () {
      final issues = validateDocument({
        // no version
        'blocks': [
          {'title': 'no type'}, // missing type
          {'type': 'callout', 'blocks': []}, // reserved keyword as field
        ],
        'views': {
          'a': {'present': 'popover', 'blocks': []}, // bad present
        },
      });
      final paths = issues.map((i) => i.path).toList();
      expect(paths, contains('version'));
      expect(paths, contains('blocks[0].type'));
      expect(paths, contains('blocks[1].blocks'));
      expect(paths, contains('views.a.present'));
      expect(issues.length, greaterThanOrEqualTo(4));
    });
  });
}
