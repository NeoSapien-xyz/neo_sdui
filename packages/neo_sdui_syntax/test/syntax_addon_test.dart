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
