import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';
import 'package:neo_sdui_syntax/neo_sdui_syntax.dart';

BlockNode _code(String content, {String? language, String? label}) => BlockNode(
      type: 'code',
      fields: {'content': content, 'language': ?language, 'label': ?label},
    );

Future<void> _pump(WidgetTester tester, BlockBuilder builder, BlockNode node) {
  return tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 360,
            height: 240,
            child: NeoSduiScope(
              theme: NeoSduiTheme.fallback(),
              dispatch: (_, _) {},
              buildBlocks: (_) => const [],
              child: Builder(builder: (context) => builder(context, node)),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final addonCode = NeoSdui.compose([neoSduiSyntaxAddon]).registry.builderFor('code')!;
  final coreCode = NeoSdui.compose(const []).registry.builderFor('code')!;

  testWidgets('honours theme.code: fill, copy glyph (no Copy text), wraps under it',
      (tester) async {
    const fill = Color(0xFF0B0C0C);
    final theme = NeoSduiTheme.fallback().copyWith(
      code: NeoCodeStyle(
        fill: fill,
        wrap: false,
        padding: const EdgeInsets.fromLTRB(16, 14, 44, 14),
        copyGlyph: (size, c) =>
            SizedBox(key: const Key('glyph'), width: size, height: size),
      ),
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Center(
          child: SizedBox(
            width: 300,
            child: NeoSduiScope(
              theme: theme,
              dispatch: (_, _) {},
              buildBlocks: (_) => const [],
              child: Builder(
                  builder: (c) => addonCode(
                      c,
                      _code(
                          'https://api.neosapien.xyz/mcp/very/long/path/that/would/wrap/on/a/narrow/box'))),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('Copy'), findsNothing);
    expect(find.byKey(const Key('glyph')), findsOneWidget);
    final d = tester
        .widget<DecoratedBox>(find
            .descendant(
                of: find.byType(NeoSduiScope), matching: find.byType(DecoratedBox))
            .first)
        .decoration as BoxDecoration;
    expect(d.color, fill);
    final h = tester
        .getSize(find.textContaining('https://api', findRichText: true))
        .height;
    // An overlaid copy glyph forces wrap even with `wrap: false` (core
    // code.dart: no part of the command hides behind the button), so the long
    // URL takes more than one line.
    expect(h, greaterThan(25));
  });

  group('add-on present', () {
    testWidgets('overrides code: renders content, language badge, copy chip',
        (tester) async {
      await _pump(tester, addonCode,
          _code('{ "mcpServers": {} }', language: 'json', label: 'Config'));
      expect(find.text('Config'), findsOneWidget);
      // HighlightView paints the content as colored spans in one RichText, so
      // match its concatenated plain text rather than a bare Text widget.
      expect(find.text('{ "mcpServers": {} }', findRichText: true),
          findsOneWidget);
      expect(find.byKey(const Key('syntax-language')), findsOneWidget);
      expect(find.text('json'), findsOneWidget);
      expect(find.byKey(const Key('code-copy')), findsOneWidget);
    });

    testWidgets('language badge sits inside the code box', (tester) async {
      await _pump(tester, addonCode, _code('ls', language: 'bash'));
      // The code box is the outermost DecoratedBox around the highlighted text.
      final box = tester.getRect(find
          .ancestor(
              of: find.text('ls', findRichText: true),
              matching: find.byType(DecoratedBox))
          .last);
      final badge = tester.getRect(find.byKey(const Key('syntax-language')));
      expect(box.contains(badge.topLeft) && box.contains(badge.bottomRight),
          isTrue,
          reason: 'badge $badge outside code box $box');
    });

    testWidgets('no language -> no badge, still copyable', (tester) async {
      await _pump(tester, addonCode, _code('npm i -g x'));
      expect(find.byKey(const Key('syntax-language')), findsNothing);
      expect(find.byKey(const Key('code-copy')), findsOneWidget);
    });

    testWidgets('copies content and confirms', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await _pump(tester, addonCode, _code('claude mcp list', language: 'bash'));
      await tester.tap(find.byKey(const Key('code-copy')));
      await tester.pump();
      await tester.pump();
      expect(copied, 'claude mcp list');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2)); // clear the reset timer
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
  });

  group('add-on absent (degrade)', () {
    testWidgets('core code renders content + copy, no language badge',
        (tester) async {
      await _pump(tester, coreCode, _code('npm i -g x', language: 'bash'));
      expect(find.text('npm i -g x'), findsOneWidget);
      expect(find.byKey(const Key('code-copy')), findsOneWidget);
      expect(find.byKey(const Key('syntax-language')), findsNothing);
    });
  });
}
