import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

const _url = 'https://claude.ai/directory/neosapien';

final _actions = <NeoAction>[];

Future<void> _pump(
  WidgetTester tester,
  Object? link, {
  NeoSduiTheme? theme,
  double width = 400,
}) async {
  _actions.clear();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: width,
            height: 600,
            child: NeoSduiView(
              document: NeoDocument.fromJson({
                'version': 1,
                'blocks': [
                  {
                    'type': 'steps',
                    'items': [
                      {'caption': 'Open it', 'link': link},
                    ],
                  },
                ],
              }),
              theme: theme ?? NeoSduiTheme.fallback(),
              onAction: (_, a) => _actions.add(a),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Records clipboard writes through the platform channel.
List<String> _mockClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return copied;
}

Finder get _copyIcon => find.byKey(const Key('icon-copy'));
Finder get _checkIcon => find.byKey(const Key('icon-check'));

void main() {
  const link = {'url': _url, 'label': 'claude.ai/directory/neosapien'};

  testWidgets('copy button reads "Copy link", then "Link copied"', (t) async {
    final handle = t.ensureSemantics();
    _mockClipboard(t);
    await _pump(t, link);
    await t.pumpAndSettle();
    SemanticsNode button() => t.getSemantics(find.byWidgetPredicate((w) =>
        w is Semantics &&
        (w.properties.label == 'Copy link' ||
            w.properties.label == 'Link copied')));
    expect(button().label, 'Copy link');
    expect(button().flagsCollection.isButton, isTrue);
    await t.tap(_copyIcon);
    await t.pump();
    expect(button().label, 'Link copied');
    expect(button().flagsCollection.isLiveRegion, isTrue);
    await t.pump(const Duration(seconds: 3));
    handle.dispose();
  });

  testWidgets('a tap in the top padding above the button still copies',
      (t) async {
    final copied = _mockClipboard(t);
    await _pump(t, link);
    final r = t.getRect(_copyIcon);
    // 5px above the glyph's own box is inside the 28px button; go well past it,
    // into the 10px top padding.
    await t.tapAt(Offset(r.center.dx, r.center.dy - 14 - 5));
    await t.pump();
    expect(copied, [_url]);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping the label dispatches ExternalUrl', (t) async {
    await _pump(t, link);
    await t.tap(find.text('claude.ai/directory/neosapien'));
    expect(_actions.single, isA<ExternalUrl>());
    expect((_actions.single as ExternalUrl).url, Uri.parse(_url));
  });

  testWidgets('copy writes the url, shows a check, reverts after 2s',
      (t) async {
    final copied = _mockClipboard(t);
    await _pump(t, link);
    expect(_checkIcon, findsNothing);
    await t.tap(_copyIcon);
    await t.pump();
    expect(copied, [_url]);
    expect(_checkIcon, findsOneWidget);
    expect(_copyIcon, findsNothing);
    await t.pump(const Duration(milliseconds: 1900));
    expect(_checkIcon, findsOneWidget);
    await t.pump(const Duration(milliseconds: 200));
    expect(_copyIcon, findsOneWidget);
    expect(_checkIcon, findsNothing);
  });

  testWidgets('disposing inside the 2s window leaves no pending timer',
      (t) async {
    _mockClipboard(t);
    await _pump(t, link);
    await t.tap(_copyIcon);
    await t.pump();
    await t.pumpWidget(const SizedBox());
    // A live timer would fail the test's pending-timer check on teardown, and a
    // late setState would throw here.
    await t.pump(const Duration(seconds: 3));
    expect(t.takeException(), isNull);
  });

  testWidgets('a javascript: url is plain text: no tap, no copy button',
      (t) async {
    await _pump(t, {'url': 'javascript:alert(1)', 'label': 'click me'});
    expect(find.text('click me'), findsOneWidget);
    expect(_copyIcon, findsNothing);
    await t.tap(find.text('click me'));
    expect(_actions, isEmpty);
  });

  testWidgets('a missing label shows the url', (t) async {
    await _pump(t, {'url': _url});
    expect(find.text(_url), findsOneWidget);
  });

  testWidgets('a long label ellipsises on one line', (t) async {
    await _pump(t, {'url': _url, 'label': 'very long ' * 40}, width: 300);
    final text = t.widget<Text>(find.textContaining('very long'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(t.takeException(), isNull);
  });

  testWidgets('a non-map link renders the step without a row', (t) async {
    await _pump(t, 'x');
    expect(find.text('Open it'), findsOneWidget);
    expect(_copyIcon, findsNothing);
    expect(find.text('x'), findsNothing);
  });

  testWidgets('a carded step carries the row too', (t) async {
    await _pump(
      t,
      link,
      theme: NeoSduiTheme.fallback()
          .copyWith(stepCardColor: const Color(0x05FFFFFF)),
    );
    expect(_copyIcon, findsOneWidget);
    expect(find.text('claude.ai/directory/neosapien'), findsOneWidget);
  });
}
