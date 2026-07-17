import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The theme's text roles. A block may `copyWith` a *role* onto one of these
/// (a color, a weight) — it may never `copyWith` a *type constant* over one.
const _textRoles = {'title', 'subtitle', 'body', 'caption', 'mono'};

/// The properties that are the type scale itself, and are therefore the theme's
/// alone. `fontWeight` is deliberately absent: `copyWith(fontWeight: w500)` is a
/// semantic emphasis pick over the role (the `bodyEmphasis` idiom), used at ~12
/// legitimate sites, so gating it would make this check noise rather than signal.
const _typeProps = {'fontSize', 'letterSpacing', 'fontFamily'};

/// Escape hatch for the one honest exception: sizing a *glyph* (a '›' chevron, a
/// badge digit) is icon geometry that happens to ride a TextStyle, not the type
/// scale. Mark the site `// geometry:` with a reason — the marker is the
/// justification, and a new one has to be written on purpose.
const _exempt = 'geometry:';

/// Every `theme.<textRole>.copyWith(...)` in [src] carrying a type property,
/// as `line: args`. Walks the parens so a nested call can't truncate the args.
Map<int, String> _bakedType(String src) {
  final out = <int, String>{};
  final call = RegExp(r'theme\.(\w+)\s*\.copyWith\(');
  for (final m in call.allMatches(src)) {
    if (!_textRoles.contains(m.group(1))) continue;
    var depth = 1;
    var i = m.end;
    for (; i < src.length && depth > 0; i++) {
      if (src[i] == '(') depth++;
      if (src[i] == ')') depth--;
    }
    final args = src.substring(m.end, i - 1);
    if (!_typeProps.any((p) => args.contains('$p:'))) continue;
    // The marker may sit in the args or in the comment block right above.
    final head = src.lastIndexOf('\n\n', m.start);
    if (src.substring(head < 0 ? 0 : head, i).contains(_exempt)) continue;
    out['\n'.allMatches(src.substring(0, m.start)).length + 1] = args;
  }
  return out;
}

void main() {
  // The 26% bucket: an existing theme slot holding a *fabricated* value. Every
  // letterSpacing in the system was exactly -4.00% of its font size across 7
  // values — one broadcast constant, propagated. A block that bakes 14/-0.56
  // over `theme.body` puts that number beyond the reach of every figwire output:
  // no ledger observation, no wire field, no app theme can move it. The block
  // picks a *role*; the theme owns what the role measures.
  test('no block bakes a type constant over a theme text role', () {
    final offenders = <String>[];
    for (final f in Directory('lib/src/blocks').listSync().whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      _bakedType(f.readAsStringSync()).forEach((line, args) {
        offenders.add('${f.path}:$line — copyWith($args)');
      });
    }
    expect(offenders, isEmpty,
        reason: 'Baked type over a theme role — unreachable from any theme.\n'
            'Use the role whose scale you want (title/body/caption), or mark the\n'
            'site `// geometry:` if it sizes a glyph rather than text:\n'
            '${offenders.join('\n')}');
  });

  test('the check fires on a baked constant and not on its neighbours', () {
    // Fires: the shape that shipped (cta/card/header before this test landed).
    expect(_bakedType('theme.body.copyWith(fontSize: 14, letterSpacing: -0.56)'),
        hasLength(1));
    expect(_bakedType('final s = theme.title\n  .copyWith(fontFamily: "X");'),
        hasLength(1));
    // Silent: a role pick, a non-theme receiver, a marked glyph, a nested call.
    expect(_bakedType('theme.body.copyWith(fontWeight: FontWeight.w500)'), isEmpty);
    expect(_bakedType('style.copyWith(color: const Color(0xFFFFFFFF))'), isEmpty);
    expect(_bakedType('// geometry: badge\ntheme.caption.copyWith(fontSize: 11)'),
        isEmpty);
    expect(_bakedType('theme.body.copyWith(color: f(a, b))'), isEmpty);
  });
}
