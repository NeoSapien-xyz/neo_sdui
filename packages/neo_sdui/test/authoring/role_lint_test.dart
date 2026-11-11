import 'package:flutter_test/flutter_test.dart';
import 'package:neo_sdui/neo_sdui.dart';

Observation _accent(String name, String hex, String page) => Observation(
    roleKey: 'accents.$name',
    value: hex,
    page: page,
    provenance: Provenance.variable,
    kind: ValueKind.color);

void main() {
  test('a wire tone with a matching theme accent is clean', () {
    final r = (RoleLedger()
          ..observe(_accent('brand', '0xFF7A5CFF', 'home'))
          ..useRole('home', 'tone:brand'))
        .reconcile();
    expect(lintRoleDrift(r).where((i) => i.isBlocking), isEmpty);
  });

  test('a wire tone with no theme accent is a blocking issue', () {
    final r = (RoleLedger()
          ..observe(Observation(
              roleKey: 'accent',
              value: '0xFF00F1A0',
              page: 'home',
              provenance: Provenance.variable,
              kind: ValueKind.color))
          ..useRole('home', 'tone:brand')) // brand never declared
        .reconcile();
    final blocking = lintRoleDrift(r).where((i) => i.isBlocking).toList();
    expect(blocking, hasLength(1));
    expect(blocking.single.role, 'tone:brand');
  });

  test('built-in tones accent/critical always resolve', () {
    final r = (RoleLedger()
          ..useRole('home', 'tone:accent')
          ..useRole('home', 'tone:critical'))
        .reconcile();
    expect(lintRoleDrift(r).where((i) => i.isBlocking), isEmpty);
  });

  test('a default-set icon resolves; an unmapped icon is a blocking issue', () {
    final r = (RoleLedger()
          ..useRole('home', 'icon:sparkle') // in kDefaultIcons
          ..useRole('home', 'icon:unicorn')) // not mapped anywhere
        .reconcile();
    final blocking = lintRoleDrift(r).where((i) => i.isBlocking).toList();
    expect(blocking, hasLength(1));
    expect(blocking.single.role, 'icon:unicorn');
  });

  test('a theme accent no wire uses is an advisory (non-blocking)', () {
    final r = (RoleLedger()..observe(_accent('brand', '0xFF7A5CFF', 'home')))
        .reconcile();
    final issues = lintRoleDrift(r);
    expect(issues.where((i) => i.isBlocking), isEmpty);
    expect(issues.any((i) => i.role == 'accents.brand' && !i.isBlocking), isTrue);
  });

  test('a wire icon resolved only through glyphs.<name> is clean', () {
    final r = (RoleLedger()
          ..observe(const Observation(
              roleKey: 'glyphs.link',
              value: '(s, c) => const SizedBox()',
              page: 'home',
              provenance: Provenance.measured,
              kind: ValueKind.other))
          ..useRole('home', 'icon:link'))
        .reconcile();
    expect(lintRoleDrift(r), isEmpty);
  });
}
