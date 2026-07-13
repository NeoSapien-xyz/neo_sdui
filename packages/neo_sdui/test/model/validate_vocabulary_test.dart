import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

void main() {
  group('validateWireVocabulary', () {
    test('an off-roster type is a hard-block issue naming the path', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {'type': 'banner', 'title': 'x'},
        ],
      });
      expect(issues, hasLength(1));
      expect(issues.single.isBlocking, isTrue);
      expect(issues.single.path, 'blocks[0].type');
    });

    test('a valid 14-type doc yields no issues', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {'type': 'header', 'title': 'Hi'},
          {'type': 'text', 'body': 'copy'},
          {'type': 'spacer'},
        ],
      });
      expect(issues, isEmpty);
    });

    test('missing required fields are warnings, not hard blocks', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {'type': 'header'}, // no title
          {'type': 'code'}, // no content
          {
            'type': 'steps',
            'items': [
              {'detail': 'no caption'},
            ],
          },
        ],
      });
      expect(issues, hasLength(3));
      expect(issues.every((i) => !i.isBlocking), isTrue);
    });

    test('an off-roster type nested in tabs, children, and fallback is caught',
        () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'tabs',
            'tabs': [
              {
                'label': 'a',
                'blocks': [
                  {'type': 'bad1'},
                ],
              },
            ],
          },
          {
            'type': 'group',
            'children': [
              {'type': 'bad2'},
            ],
          },
          {
            'type': 'header',
            'title': 'x',
            'fallback': {'type': 'bad3'},
          },
        ],
      });
      final blocking = issues.where((i) => i.isBlocking).toList();
      expect(blocking, hasLength(3));
      expect(
        blocking.map((i) => i.path),
        containsAll([
          'blocks[0].tabs[0].blocks[0].type',
          'blocks[1].children[0].type',
          'blocks[2].fallback.type',
        ]),
      );
    });

    test('steps/faq items are leaf maps, not nested blocks', () {
      // A stray `type` on an item must NOT be recursed as a block.
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'faq',
            'items': [
              {'question': 'q', 'answer': 'a', 'type': 'banner'},
            ],
          },
        ],
      });
      expect(issues, isEmpty);
    });

    test('non-map block and non-list blocks degrade to an issue, never throw',
        () {
      expect(() {
        final a = validateWireVocabulary({
          'version': 1,
          'blocks': ['nope'],
        });
        expect(a.single.isBlocking, isTrue);

        final b = validateWireVocabulary({'version': 1, 'blocks': 'not a list'});
        expect(b, isEmpty); // validateDocument flags the shape; nothing to walk
      }, returnsNormally);
    });

    test('composes with validateDocument on a clean doc', () {
      final doc = {
        'version': 1,
        'blocks': [
          {'type': 'card', 'title': 'FAQs', 'action': 'screen:faq'},
        ],
        'views': {
          'faq': {
            'present': 'screen',
            'blocks': [
              {'type': 'header', 'title': 'FAQs'},
            ],
          },
        },
      };
      expect(validateDocument(doc), isEmpty);
      expect(validateWireVocabulary(doc), isEmpty);
    });

    test('an off-roster type inside a view is caught with a view path', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': <Object?>[],
        'views': {
          'faq': {
            'blocks': [
              {'type': 'nope'},
            ],
          },
        },
      });
      expect(issues.single.path, 'views.faq.blocks[0].type');
      expect(issues.single.isBlocking, isTrue);
    });

    test('kCoreBlockTypes matches the registered roster count', () {
      expect(kCoreBlockTypes, hasLength(14));
    });
  });
}
