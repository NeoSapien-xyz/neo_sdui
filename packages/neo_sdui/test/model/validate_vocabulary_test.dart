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

    test('a valid doc yields no issues', () {
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

    test("an item's own stray `type` is not recursed as a block", () {
      // The item MAP itself is leaf content — a stray `type` on it must NOT be
      // recursed. Only a step item's explicit `blocks` list is a carrier (below).
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'faq',
            'items': [
              {'question': 'q', 'answer': 'a', 'type': 'banner'},
            ],
          },
          {
            'type': 'steps',
            'items': [
              {'caption': 'c', 'type': 'banner'},
            ],
          },
        ],
      });
      expect(issues, isEmpty);
    });

    test('a step `link` that is not a map with a `url` warns', () {
      for (final bad in <Object?>[
        'x',
        <String, Object?>{'label': 'no url'},
        <String, Object?>{'url': ''},
      ]) {
        final issues = validateWireVocabulary({
          'version': 1,
          'blocks': [
            {
              'type': 'steps',
              'items': [
                {'caption': 'c', 'link': bad},
              ],
            },
          ],
        });
        expect(issues, hasLength(1), reason: '$bad');
        expect(issues.single.isBlocking, isFalse);
        expect(issues.single.path, 'blocks[0].items[0].link');
      }
    });

    test('a step `link` with a url is sound', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'steps',
            'items': [
              {
                'caption': 'c',
                'link': {'url': 'https://a.b'},
              },
            ],
          },
        ],
      });
      expect(issues, isEmpty);
    });

    test('an off-roster type inside a step item `blocks` is caught', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'steps',
            'items': [
              {'caption': 'ok'},
              {
                'caption': 'card',
                'blocks': [
                  {'type': 'banner'},
                ],
              },
            ],
          },
        ],
      });
      expect(issues, hasLength(1));
      expect(issues.single.isBlocking, isTrue);
      expect(issues.single.path, 'blocks[0].items[1].blocks[0].type');
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

    test('accordion: missing title or empty children warns', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {'type': 'accordion', 'children': [{'type': 'text', 'body': 'x'}]},
          {'type': 'accordion', 'title': 'T', 'children': []},
        ],
      });
      expect(issues, hasLength(2));
      expect(issues.every((i) => !i.isBlocking), isTrue);
    });

    test('accordion: unknown child type blocks, fallback is recursed', () {
      final issues = validateWireVocabulary({
        'version': 1,
        'blocks': [
          {
            'type': 'accordion',
            'title': 'T',
            'children': [
              {'type': 'nope'},
            ],
            'fallback': {'type': 'column', 'children': [{'type': 'nope2'}]},
          },
        ],
      });
      expect(issues.map((i) => i.path), [
        'blocks[0].children[0].type',
        'blocks[0].fallback.children[0].type',
      ]);
      expect(issues.every((i) => i.isBlocking), isTrue);
    });

    test('kCoreBlockTypes matches the registered roster count', () {
      expect(kCoreBlockTypes, hasLength(15));
    });
  });
}
