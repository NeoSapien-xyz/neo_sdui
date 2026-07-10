import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

void main() {
  group('NeoAction.parse — https-only guard (R13 / AE5)', () {
    test('https link is accepted', () {
      final a = NeoAction.parse('https://neosapien.xyz/docs');
      expect(a, isA<ExternalUrl>());
      expect((a as ExternalUrl).url.host, 'neosapien.xyz');
    });

    test('non-https schemes are rejected, nothing launches', () {
      for (final raw in [
        'http://neosapien.xyz',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'intent://evil',
        'neo://profile',
        'tel:123',
      ]) {
        expect(NeoAction.parse(raw), isA<InvalidAction>(), reason: raw);
      }
    });
  });

  group('NeoAction.parse — navigation grammar', () {
    test('route: resolves to a named route', () {
      expect(NeoAction.parse('route:askNeo'), isA<RouteAction>());
      expect((NeoAction.parse('route:askNeo') as RouteAction).name, 'askNeo');
    });

    test('sheet: and screen: carry their present mode', () {
      final sheet = NeoAction.parse('sheet:control');
      final screen = NeoAction.parse('screen:chatgpt');
      expect((sheet as OpenView).id, 'control');
      expect(sheet.present, NeoViewPresent.sheet);
      expect((screen as OpenView).id, 'chatgpt');
      expect(screen.present, NeoViewPresent.screen);
    });

    test('close actions parse', () {
      expect(NeoAction.parse('closeSheet'), isA<CloseView>());
      expect(NeoAction.parse('closeAll'), isA<CloseAll>());
    });

    test('empty ids and garbage are invalid', () {
      expect(NeoAction.parse('route:'), isA<InvalidAction>());
      expect(NeoAction.parse('sheet:'), isA<InvalidAction>());
      expect(NeoAction.parse(''), isA<InvalidAction>());
      expect(NeoAction.parse('not an action'), isA<InvalidAction>());
    });
  });
}
