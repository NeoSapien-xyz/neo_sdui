import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A4 — `wire-contract.md` must not drift from the blocks that read the wire.
///
/// The contract is figwire's whole picture of the vocabulary it may emit, and it
/// is hand-written. Nine fields the blocks read were never written down —
/// `text.variant:"footnote"`, `card.icon`/`card.tone`, `column`/`group`
/// `variant`, `tabs.header`, `header.align`/`cta.align`, `media.shape`,
/// `NeoView.title` — and an agent cannot emit a field it has never been told
/// exists. Each one came back as a device defect ("this 'Note:' card isn't
/// really a card", "no icons, no nothing", "the spacing is unprecedented").
///
/// A test, not a generator: the contract's prose is the part that makes it
/// usable and a generator would flatten it. This only asserts the doc mentions
/// each key **in the row of the block that reads it** — a key documented for
/// some other block is exactly the gap that shipped (`icon` was written down for
/// `header`/`callout` while `card` read it too). Values are checked doc-wide
/// (see [_valueTest]). Wording stays human.

const _contract = '../../.claude/skills/figwire/references/wire-contract.md';
const _blocksDir = 'lib/src/blocks';
const _registrySource = 'lib/src/blocks/default_registry.dart';
const _viewSource = 'lib/src/model/view.dart';

/// The wire type(s) each block source implements — the contract row(s) its keys
/// are checked against. Held to `default_registry.dart` by the guard test below.
const _typesByFile = <String, List<String>>{
  'callout.dart': ['callout'],
  'card.dart': ['card'],
  'code.dart': ['code'],
  'cta.dart': ['cta'],
  'faq.dart': ['faq'],
  'header.dart': ['header'],
  'layout.dart': ['row', 'column', 'group', 'spacer'],
  'media.dart': ['media'],
  'steps.dart': ['steps'],
  'tabs.dart': ['tabs'],
  'text.dart': ['text'],
};

/// Keys a block reads that are *not* wire vocabulary, and why — the escape hatch
/// for an internal field, so the only other way out is documenting it.
const _notWireKeys = <String, String>{};

/// Every wire key a block reads. Misses `ratioOr`, whose `ratio`/`width`/
/// `height` literals live in `block_node.dart` rather than in a block; all three
/// are already documented.
final _keyRead = RegExp(
    r"\.(?:stringOr|intOr|boolOr|nodeList|mapList)\('(\w+)'|\.fields\['(\w+)'\]");

/// A literal a block compares a wire key against — `stringOr('variant') ==
/// 'tight'`. An undocumented *value* fails exactly like an undocumented field:
/// `variant` was written down (for `card`/`spacer`) while `"list"`/`"tight"`/
/// `"footnote"` were not. Checked doc-wide, not per row: the enum vocabulary is
/// cross-cutting, and the per-block *trigger* for a value lives in the trigger
/// index rather than the block's row.
final _valueTest =
    RegExp(r"\.stringOr\('\w+'(?:,[^)]*)?\)\s*[!=]=\s*'([^']*)'");

/// The keys `NeoView.fromJson` reads off a view's JSON.
final _viewKeyRead = RegExp(r"json\['(\w+)'\]");

Set<String> _keys(String src) =>
    {for (final m in _keyRead.allMatches(src)) (m.group(1) ?? m.group(2))!};

Set<String> _values(String src) =>
    {for (final m in _valueTest.allMatches(src)) m.group(1)!};

/// The contract's table row for a block type — its documented field list.
String _row(String md, String type) =>
    RegExp('^\\|\\s*`$type`\\s*\\|.*\$', multiLine: true)
        .firstMatch(md)
        ?.group(0) ??
    '';

/// A named section of the contract, heading to next heading.
String _section(String md, String heading) {
  final start = md.indexOf(heading);
  if (start < 0) return '';
  final end = md.indexOf('\n## ', start + heading.length);
  return md.substring(start, end < 0 ? md.length : end);
}

bool _mentions(String scope, String token) =>
    RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(scope);

void main() {
  final md = File(_contract).readAsStringSync();

  test('the file→type map still matches the registry', () {
    // Otherwise a new block type is scanned against the wrong row — or, worse,
    // not scanned at all, and the drift test goes quietly green.
    final registered = {
      for (final m in RegExp(r"register\('(\w+)'")
          .allMatches(File(_registrySource).readAsStringSync()))
        m.group(1)!,
    };
    expect(_typesByFile.values.expand((t) => t).toSet(), registered);
    for (final type in registered) {
      expect(_row(md, type), isNotEmpty,
          reason: '$_contract has no table row for the `$type` block');
    }
  });

  test('every wire key a block reads is documented for that block', () {
    final undocumented = <String>[];
    for (final entry in _typesByFile.entries) {
      final scope =
          entry.value.map((t) => _row(md, t)).join('\n'); // that block's row(s)
      final src = File('$_blocksDir/${entry.key}').readAsStringSync();
      for (final key in _keys(src)) {
        if (_notWireKeys.containsKey(key) || _mentions(scope, key)) continue;
        undocumented.add('${entry.value.join('/')}.$key');
      }
    }
    undocumented.sort();
    expect(undocumented, isEmpty,
        reason: 'blocks read wire fields the contract never documents for them: '
            '${undocumented.join(', ')} — add each to its row in $_contract '
            '(or, if it is not a wire field, to _notWireKeys with a reason). '
            'A field documented on some other block is the gap that shipped.');
  });

  test('every value a block matches the wire against is documented', () {
    final undocumented = <String>[];
    for (final file in _typesByFile.keys) {
      for (final v in _values(File('$_blocksDir/$file').readAsStringSync())) {
        if (!_mentions(md, v)) undocumented.add('$file: "$v"');
      }
    }
    undocumented.sort();
    expect(undocumented, isEmpty,
        reason: 'blocks branch on wire values the contract never names: '
            '${undocumented.join(', ')} — a value the wire may carry but the '
            'contract omits cannot be emitted. Document each in $_contract.');
  });

  test('every key NeoView reads off the wire is documented', () {
    final scope = _section(md, '## Document shape');
    final src = File(_viewSource).readAsStringSync();
    final undocumented = [
      for (final m in _viewKeyRead.allMatches(src))
        if (!_mentions(scope, m.group(1)!)) m.group(1)!,
    ]..sort();
    expect(undocumented, isEmpty,
        reason: 'NeoView reads undocumented view fields: '
            '${undocumented.join(', ')} — document them under "Document shape" '
            'in $_contract.');
  });
}
