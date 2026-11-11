import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _probe = Key('chevron-probe');

NeoSduiTheme _theme({bool reduceMotion = false, bool carded = false}) =>
    NeoSduiTheme.fallback().copyWith(
      reduceMotion: reduceMotion,
      stepCardColor: carded ? const Color(0x05FFFFFF) : null,
      accordion: NeoAccordionStyle(
        chevron: (size, color) =>
            ColoredBox(key: _probe, color: color, child: SizedBox.square(dimension: size)),
      ),
    );

Map<String, Object?> _accordion(List<Object?> children, {Object? title = 'Advanced'}) => {
      'type': 'accordion',
      'title': title,
      'children': children,
    };

Future<void> _pump(
  WidgetTester tester,
  List<Map<String, Object?>> blocks, {
  NeoSduiTheme? theme,
  BlockRegistry? registry,
}) =>
    tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Center(
            child: SizedBox(
              width: 400,
              height: 1200,
              child: NeoSduiView(
                document: NeoDocument.fromJson({'version': 1, 'blocks': blocks}),
                theme: theme ?? _theme(),
                registry: registry,
                onAction: (_, _) {},
              ),
            ),
          ),
        ),
      ),
    );

Map<String, Object?> _text(String s) => {'type': 'text', 'body': s};

double _turns(WidgetTester tester) =>
    tester.widget<AnimatedRotation>(find.byType(AnimatedRotation)).turns;

Color _caretColor(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(_probe)).color;

void main() {
  testWidgets('starts closed: title shows, children are not built', (tester) async {
    await _pump(tester, [_accordion([_text('inside')])]);
    await tester.pumpAndSettle();
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('inside'), findsNothing);
  });

  testWidgets('tap opens: children show, caret turns half and goes accent', (tester) async {
    final theme = _theme();
    await _pump(tester, [_accordion([_text('inside')])], theme: theme);
    await tester.pumpAndSettle();
    expect(_turns(tester), 0);
    expect(_caretColor(tester), theme.textMuted);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('inside'), findsOneWidget);
    expect(_turns(tester), 0.5);
    expect(_caretColor(tester), theme.accent);
  });

  testWidgets('second tap removes the children in the same frame', (tester) async {
    await _pump(tester, [_accordion([_text('inside')])]);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pump();
    expect(find.text('inside'), findsNothing);
  });

  testWidgets('reduceMotion: open shows children with no animation pending', (tester) async {
    await _pump(tester, [_accordion([_text('inside')])],
        theme: _theme(reduceMotion: true));
    await tester.tap(find.text('Advanced'));
    await tester.pump();
    expect(find.text('inside'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('head is a button reporting expanded state', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, [_accordion([_text('inside')])]);
    await tester.pumpAndSettle();
    SemanticsNode head() => tester.getSemantics(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'Advanced'));
    expect(head().flagsCollection.isButton, isTrue);
    expect(head().flagsCollection.isExpanded, Tristate.isFalse);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(head().flagsCollection.isExpanded, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('a child that throws is isolated, siblings render', (tester) async {
    final registry = defaultRegistry()
      ..register('boom', (_, _) => throw StateError('boom'));
    await _pump(
      tester,
      [
        _accordion([
          _text('before'),
          {'type': 'boom'},
          _text('after'),
        ]),
      ],
      registry: registry,
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('before'), findsOneWidget);
    expect(find.text('after'), findsOneWidget);
  });

  testWidgets('a steps block inside keeps carded rendering', (tester) async {
    await _pump(
      tester,
      [
        _accordion([
          {'type': 'steps', 'items': [{'caption': 'One'}]},
        ]),
      ],
      theme: _theme(carded: true),
    );
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Step 0:'), findsOneWidget);
  });

  testWidgets('title takes runs', (tester) async {
    await _pump(tester, [
      _accordion([_text('inside')], title: [
        'Advanced: ',
        {'text': 'manual', 'tone': 'strong'},
      ]),
    ]);
    await tester.pumpAndSettle();
    expect(find.textContaining('Advanced', findRichText: true), findsOneWidget);
  });

  testWidgets('an old registry without accordion renders the fallback', (tester) async {
    final old = defaultRegistry();
    old.register('accordion', (_, _) => throw StateError('unregistered'));
    await _pump(
      tester,
      [
        {
          ..._accordion([_text('inside')]),
          'fallback': {
            'type': 'column',
            'children': [_text('plain fallback')],
          },
        },
      ],
      registry: old,
    );
    await tester.pumpAndSettle();
    expect(find.text('plain fallback'), findsOneWidget);
  });
}
