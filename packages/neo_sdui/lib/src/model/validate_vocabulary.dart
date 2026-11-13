/// Strict wire-vocabulary check, layered on `validateDocument` (which is
/// structural only — it accepts any non-empty `type` string). This enforces the
/// fixed core block roster and each type's required content, so a mis-classified
/// block cannot pass as "validated" and then silently vanish in the renderer
/// (which drops unknown types to `SizedBox.shrink`).
///
/// Authored contract: the block builders enforce nothing — every field is read
/// through a guarded default — so the required-field table below is a new
/// contract, not derived from the builders.
library;

/// How a vocabulary issue should be treated by a caller (e.g. the generator
/// skill's write gate).
enum WireIssueSeverity {
  /// Off-roster `type`: the renderer drops the block, so it would vanish from
  /// the output. Hard — a caller should refuse to write.
  block,

  /// Missing required content: the renderer degrades the block to
  /// empty/collapsed, which a human sees in the preview and report. Advisory.
  warn,
}

/// One vocabulary problem. Collected, never thrown.
class WireVocabIssue {
  const WireVocabIssue(this.path, this.message, this.severity);

  /// Location, e.g. `blocks[2].tabs[0].blocks[1].type`.
  final String path;
  final String message;
  final WireIssueSeverity severity;

  bool get isBlocking => severity == WireIssueSeverity.block;

  @override
  String toString() => '$path: $message [${isBlocking ? 'block' : 'warn'}]';
}

/// The core block roster — mirrors `defaultRegistry()`. Add-ons re-register
/// existing types (last-wins) rather than introducing new `type` strings, so a
/// core-only allowlist is correct for both core and add-on-composed engines.
const Set<String> kCoreBlockTypes = {
  'header', 'text', 'cta', 'callout', 'media', 'code', 'card',
  'steps', 'faq', 'accordion', 'tabs', 'row', 'column', 'group', 'spacer', //
};

const Set<String> _layoutTypes = {'row', 'column', 'group', 'accordion'};

/// Check every block in a decoded document against the roster and required-field
/// table. Recurses the real `BlockNode` carriers — top-level `blocks`, each
/// view's `blocks`, `children`, each `tabs[].blocks`, each `steps` item's
/// optional `blocks`, and every block's `fallback`. `faq` items and a step's
/// caption/detail/code stay leaf content. Empty result = sound. Never throws.
List<WireVocabIssue> validateWireVocabulary(Map<String, Object?> json) {
  final issues = <WireVocabIssue>[];

  final blocks = json['blocks'];
  if (blocks is List) {
    for (var i = 0; i < blocks.length; i++) {
      _checkBlock(blocks[i], 'blocks[$i]', issues);
    }
  }

  final views = json['views'];
  if (views is Map) {
    views.forEach((id, view) {
      if (view is Map && view['blocks'] is List) {
        final vb = view['blocks'] as List;
        for (var i = 0; i < vb.length; i++) {
          _checkBlock(vb[i], 'views.$id.blocks[$i]', issues);
        }
      }
    });
  }

  return issues;
}

void _checkBlock(Object? block, String path, List<WireVocabIssue> out) {
  if (block is! Map) {
    out.add(WireVocabIssue(path, 'block must be a map', WireIssueSeverity.block));
    return;
  }

  final type = block['type'];
  if (type is! String || !kCoreBlockTypes.contains(type)) {
    final shown = type is String ? type : '';
    out.add(WireVocabIssue(
      '$path.type',
      "'$shown' is not one of the ${kCoreBlockTypes.length} core block types",
      WireIssueSeverity.block,
    ));
    _checkFallback(block, path, out); // a valid fallback can still carry issues
    return;
  }

  for (final msg in _missingRequired(type, block)) {
    out.add(WireVocabIssue(path, msg, WireIssueSeverity.warn));
  }

  // Recurse only the carriers the renderer actually traverses.
  if (_layoutTypes.contains(type)) {
    _checkChildList(block['children'], '$path.children', out);
  } else if (type == 'tabs') {
    final tabs = block['tabs'];
    if (tabs is List) {
      for (var i = 0; i < tabs.length; i++) {
        final t = tabs[i];
        if (t is Map) _checkChildList(t['blocks'], '$path.tabs[$i].blocks', out);
      }
    }
    // The shared `header` rides above every tab and is built like any child
    // list — recurse it, else an off-roster block inside `tabs.header` renders
    // nothing yet passes the gate (the silent-drop this whole check prevents).
    _checkChildList(block['header'], '$path.header', out);
  } else if (type == 'steps') {
    // A step item is a leaf content map EXCEPT its optional `blocks` list, which
    // the renderer builds like any child blocks — recurse those so an off-roster
    // type inside a step-1 card is caught, same as `children`/`tabs`.
    final items = block['items'];
    if (items is List) {
      for (var i = 0; i < items.length; i++) {
        final it = items[i];
        if (it is! Map) continue;
        _checkChildList(it['blocks'], '$path.items[$i].blocks', out);
        final link = it['link'];
        if (link != null && !(link is Map && _webUrl(link['url']))) {
          out.add(WireVocabIssue('$path.items[$i].link',
              '`link` needs an http(s) `url`; the step renders without a link row',
              WireIssueSeverity.warn));
        }
        // An inline caption run's `link` (the PWA's `<a>`) must be http(s) too,
        // or it renders as plain, untappable text.
        final cap = it['caption'];
        if (cap is List) {
          for (var j = 0; j < cap.length; j++) {
            final r = cap[j];
            if (r is Map && r.containsKey('link') && !_webUrl(r['link'])) {
              out.add(WireVocabIssue('$path.items[$i].caption[$j].link',
                  'run `link` needs an http(s) url; the run renders untappable',
                  WireIssueSeverity.warn));
            }
          }
        }
      }
    }
  }
  _checkFallback(block, path, out);
}

void _checkFallback(Map block, String path, List<WireVocabIssue> out) {
  final fb = block['fallback'];
  if (fb is Map) _checkBlock(fb, '$path.fallback', out);
}

void _checkChildList(Object? list, String path, List<WireVocabIssue> out) {
  if (list is! List) return;
  for (var i = 0; i < list.length; i++) {
    _checkBlock(list[i], '$path[$i]', out);
  }
}

/// Messages for each missing required field on [block], or empty when sound.
List<String> _missingRequired(String type, Map block) {
  switch (type) {
    case 'header':
      return _text(block, 'title') ? const [] : ['`header` needs a `title`'];
    case 'text':
      return _text(block, 'body') ? const [] : ['`text` needs a `body`'];
    case 'cta':
      return _str(block, 'label') ? const [] : ['`cta` needs a `label`'];
    case 'callout':
      return _str(block, 'title') || _nonEmptyList(block, 'bullets')
          ? const []
          : ['`callout` needs a `title` or non-empty `bullets`'];
    case 'media':
      return _str(block, 'url') ? const [] : ['`media` needs a `url`'];
    case 'code':
      return _str(block, 'content') ? const [] : ['`code` needs `content`'];
    case 'card':
      return _str(block, 'title') ? const [] : ['`card` needs a `title`'];
    case 'steps':
      return _items(block, 'steps', (m) => _text(m, 'caption'),
          'each item needs a `caption`');
    case 'faq':
      return _items(block, 'faq', (m) => _str(m, 'question') && _str(m, 'answer'),
          'each item needs a `question` and `answer`');
    case 'tabs':
      final t = block['tabs'];
      if (t is! List || t.isEmpty) return ['`tabs` needs non-empty `tabs`'];
      final msgs = <String>[];
      for (var i = 0; i < t.length; i++) {
        final tab = t[i];
        if (tab is! Map || tab['blocks'] is! List) {
          msgs.add('`tabs[$i]` needs a `blocks` list');
        }
      }
      return msgs;
    case 'accordion':
      return [
        if (!_text(block, 'title')) '`accordion` needs a `title`',
        if (!_nonEmptyList(block, 'children'))
          '`accordion` needs non-empty `children`',
      ];
    case 'row':
    case 'column':
    case 'group':
      return _nonEmptyList(block, 'children')
          ? const []
          : ['`$type` needs non-empty `children`'];
    default:
      return const []; // spacer: no required fields
  }
}

List<String> _items(
    Map block, String type, bool Function(Map) ok, String each) {
  final items = block['items'];
  if (items is! List || items.isEmpty) return ['`$type` needs non-empty `items`'];
  for (final it in items) {
    if (it is! Map || !ok(it)) return ['`$type`: $each'];
  }
  return const [];
}

/// A plain string field with content.
bool _str(Map m, String k) => m[k] is String && (m[k] as String).isNotEmpty;

/// A string-or-runs field with content (a non-empty String or a non-empty List).
bool _text(Map m, String k) =>
    (m[k] is String && (m[k] as String).isNotEmpty) ||
    (m[k] is List && (m[k] as List).isNotEmpty);

bool _nonEmptyList(Map m, String k) => m[k] is List && (m[k] as List).isNotEmpty;

/// An http/https URL with a host — the only links the renderer makes tappable.
bool _webUrl(Object? v) {
  final uri = v is String ? Uri.tryParse(v) : null;
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}
