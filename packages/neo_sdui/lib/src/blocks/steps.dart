import 'package:flutter/widgets.dart';

import '../model/block_node.dart';
import '../theme/neo_sdui_scope.dart';
import '../theme/neo_sdui_theme.dart';
import '_gradient_text.dart';
import 'code.dart';

/// how_to's default thumbnail ratio when a step image omits one (matches media).
const double _defaultImageRatio = 358 / 221;

/// steps: numbered captions, each with an optional full-width `image` above the
/// row and/or a nested `blocks` list below it (composed content — a grid `group`
/// + `row` + `code` — where a baked image won't do). `layout:"row"` lays the
/// steps side by side (the compact 1·2·3 setup strip) instead of the default
/// vertical checklist. Each item builds in its own try/catch so one bad item
/// can't take out the rest (R8).
Widget buildSteps(BuildContext context, BlockNode node) {
  final scope = NeoSduiScope.of(context);
  final theme = scope.theme;
  final items = node.mapList('items');
  // The number badges' accent hue; default `accent`, but a screen can name a
  // second hue (e.g. `"brand"`) so step counts differ from accent headings.
  final numberTone = node.stringOr('tone') ?? 'accent';
  // Horizontal strip: equal-width cells (numbered badge over caption) in a Row.
  if (node.stringOr('layout') == 'row') {
    final carded = theme.stepCardColor != null;
    final row = Row(
      // Carded cells stretch to the tallest so the boxes align — a step whose
      // caption wraps to two lines doesn't leave its neighbours short. Bare
      // cells keep top-alignment (the how_to look), unchanged.
      crossAxisAlignment:
          carded ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: theme.spaceMd),
          Expanded(child: _cell(theme, i + 1, items[i], numberTone)),
        ],
      ],
    );
    return carded ? IntrinsicHeight(child: row) : row;
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
          child: _item(scope, i + 1, items[i], numberTone),
        ),
    ],
  );
}

/// One horizontal-strip cell: a circular number badge over the caption (and an
/// optional muted detail). Guards a malformed caption like the vertical `_item`
/// — a bad item keeps its badge and shows a placeholder, so numbering survives.
Widget _cell(NeoSduiTheme theme, int n, Map<String, Object?> item, String tone) {
  final cap = item['caption'];
  final caption = (cap is String || cap is List)
      ? neoText(theme, cap, theme.body)
      : Text('—', key: const Key('step-error'), style: theme.body);
  final detail = item['detail'];
  final content = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _badge(theme, n, tone),
      SizedBox(height: theme.spaceSm),
      caption,
      if (detail is String) ...[
        const SizedBox(height: 4),
        Text(detail, style: theme.caption),
      ],
    ],
  );
  // Boxed cell when the theme sets a step-card fill; otherwise bare (the how_to
  // checklist), byte-identical to before.
  final bg = theme.stepCardColor;
  if (bg == null) return content;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: bg,
      border: theme.stepCardBorderColor == null
          ? null
          : Border.all(color: theme.stepCardBorderColor!),
      borderRadius: theme.radiusMd,
    ),
    child: content,
  );
}

/// The number badge for a horizontal step: the tone-colored digit on a filled
/// 20px disc (the tone at 10% alpha — the figma step circle). Fill + digit color
/// are theme roles (via `toneColor`), never the wire.
Widget _badge(NeoSduiTheme theme, int n, String tone) {
  final c = theme.toneColor(tone);
  return Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c.withValues(alpha: 0.1),
    ),
    // Flat tone color (not the accent gradient) — the figma digit is a solid
    // hue, so this reads the role color directly rather than routing through
    // neoText's gradient path.
    child: Text('$n', style: theme.caption.copyWith(color: c, fontSize: 11)),
  );
}

Widget _item(NeoSduiScope scope, int n, Map<String, Object?> item, String numberTone) {
  final theme = scope.theme;
  // The how_to "List Item": an image-topped card whose details panel carries a
  // muted "Step n:" label + caption (and any detail/code/nested blocks). Gated
  // on the same `stepCardColor` role the row strip uses, so a theme that opts
  // into step cards gets them in both layouts; a theme without it keeps the bare
  // checklist below, byte-identical.
  if (theme.stepCardColor != null) return _cardedItem(scope, n, item, numberTone);
  final index = theme.body.copyWith(fontWeight: FontWeight.w600);
  Widget body;
  try {
    final cap = item['caption'];
    if (cap is! String && cap is! List) {
      throw StateError('step caption must be a string or a run list');
    }
    final caption = neoText(theme, cap, theme.body);
    // Optional muted sub-line and optional copyable command under the caption;
    // both absent -> caption only (R4).
    final detail = item['detail'];
    final code = item['code'];
    final extras = <Widget>[
      if (detail is String) Text(detail, style: theme.caption),
      if (code is String) ...[
        SizedBox(height: theme.spaceSm),
        codeChip(code),
      ],
    ];
    body = extras.isEmpty
        ? caption
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [caption, ...extras],
          );
  } catch (_) {
    // Bad item -> keep the number, show a placeholder, keep numbering intact.
    body = Text('—', key: const Key('step-error'), style: theme.body);
  }
  final row = Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      neoText(theme, '$n', index, tone: numberTone),
      const SizedBox(width: 12),
      Expanded(child: body),
    ],
  );
  // A step's rich content: an optional full-width baked `image` above the row
  // (the how-to screenshot), and/or a nested `blocks` list below it — composed
  // content a baked image can't be, e.g. a grid `group` wrapping a `row` + a
  // `code` command (the Claude-guide step-1 card). Both absent -> the row alone.
  final image = _stepImage(theme, item);
  final blocks = scope.buildBlocks(_stepBlocks(item));
  if (image == null && blocks.isEmpty) return row;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (image != null) ...[image, SizedBox(height: theme.spaceSm)],
      row,
      if (blocks.isNotEmpty) ...[
        SizedBox(height: theme.spaceSm),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: theme.blockSpacing),
          blocks[i],
        ],
      ],
    ],
  );
}

/// The carded vertical step — the how_to "List Item": a full-bleed image flush
/// to the card top (rounded by the card's own clip, no inner radius), then a
/// details panel with a muted "Step n:" label over the caption (and any
/// detail/code/nested blocks). All look is theme roles: `surface` fill,
/// `radiusLg`, `stepCardBorderColor` hairline, `cardShadow`. Guards a malformed
/// caption like the bare `_item`, so a bad item keeps its label + placeholder.
Widget _cardedItem(NeoSduiScope scope, int n, Map<String, Object?> item, String numberTone) {
  final theme = scope.theme;
  final cap = item['caption'];
  // Caption is white (not the muted body color), medium weight; a bare-string
  // caption also gets its URLs underlined (the figma link look).
  final capStyle =
      theme.body.copyWith(color: theme.textPrimary, fontWeight: FontWeight.w500);
  final caption = cap is String
      ? _linkedText(cap, capStyle)
      : (cap is List
          ? neoText(theme, cap, capStyle)
          : Text('—', key: const Key('step-error'), style: capStyle));
  final detail = item['detail'];
  final code = item['code'];
  final blocks = scope.buildBlocks(_stepBlocks(item));
  final body = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepLabel(theme, n),
      const SizedBox(height: 4),
      caption,
      if (detail is String) ...[
        const SizedBox(height: 4),
        Text(detail, style: theme.caption),
      ],
      if (code is String) ...[
        SizedBox(height: theme.spaceSm),
        codeChip(code),
      ],
      if (blocks.isNotEmpty) ...[
        SizedBox(height: theme.spaceSm),
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: theme.blockSpacing),
          blocks[i],
        ],
      ],
    ],
  );
  final image = _stepImage(theme, item, clip: false);
  return Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: theme.surface,
      borderRadius: theme.radiusLg,
      border: theme.stepCardBorderColor == null
          ? null
          : Border.all(color: theme.stepCardBorderColor!),
      boxShadow: theme.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?image,
        Padding(padding: const EdgeInsets.all(18), child: body),
      ],
    ),
  );
}

/// The "Step n:" label: a white->grey vertical gradient (the figma detail head),
/// painted with a ShaderMask over the bold body slot.
Widget _stepLabel(NeoSduiTheme theme, int n) {
  final style = theme.body
      .copyWith(fontWeight: FontWeight.w500, color: const Color(0xFFFFFFFF));
  return ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (b) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFFFFF), Color(0xFF999999)],
    ).createShader(b),
    child: Text('Step $n:', style: style),
  );
}

/// A step caption's URLs / bare domains drawn underlined (the figma link look) on
/// top of the caption's own [style]; caption with no url passes through as plain
/// text. Scheme URLs (`https://…`) and bare domains (`chatgpt.com`, `claude.ai`,
/// `api.neosapien.xyz/mcp`) both match.
final RegExp _urlRe = RegExp(
  r'(https?://\S+|(?:[a-z0-9-]+\.)+(?:com|ai|xyz|io|org|net|dev)(?:/\S*)?)',
  caseSensitive: false,
);
Widget _linkedText(String text, TextStyle style) {
  final matches = _urlRe.allMatches(text).toList();
  if (matches.isEmpty) return Text(text, style: style);
  final spans = <InlineSpan>[];
  var last = 0;
  for (final m in matches) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(TextSpan(
      text: m.group(0),
      style: const TextStyle(decoration: TextDecoration.underline),
    ));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return Text.rich(TextSpan(style: style, children: spans));
}

/// A step item's optional nested `blocks` -> `BlockNode`s for the resilient
/// renderer (mirrors `BlockNode.nodeList`, but reads a raw item map since step
/// items aren't `BlockNode`s). Absent/malformed -> empty, so a plain step is
/// unaffected. This is what lifts a step from a leaf caption to a composed one.
List<BlockNode> _stepBlocks(Map<String, Object?> item) {
  final raw = item['blocks'];
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is Map) BlockNode.fromJson(Map<String, Object?>.from(e)),
  ];
}

/// A step's optional `image`: a network image at its `ratio` (else the how_to
/// default), rounded to the theme radius. Missing/broken -> nothing, so a step
/// with an as-yet-unpublished asset still renders its caption. The wire carries
/// only the url + ratio role; all look is the theme's.
Widget? _stepImage(NeoSduiTheme theme, Map<String, Object?> item, {bool clip = true}) {
  final url = item['image'];
  if (url is! String || url.isEmpty) return null;
  final r = item['ratio'];
  final ratio = (r is num && r > 0 && r.isFinite) ? r.toDouble() : _defaultImageRatio;
  final img = Image.network(
    url,
    fit: BoxFit.cover,
    // Collapse — not an empty ratio box — while the asset is pending or failed,
    // so a not-yet-published image leaves no gap; reserve the ratio box only
    // once a frame arrives. AspectRatio lives on the child, never wrapping the
    // Image, so an error shrinks the whole thing away.
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
    frameBuilder: (_, child, frame, wasSync) =>
        (frame == null && !wasSync)
            ? const SizedBox.shrink()
            : AspectRatio(aspectRatio: ratio, child: child),
  );
  // Bare step: round the image itself. Carded step: the card clips the flush
  // image to its own radius, so no inner ClipRRect (double-rounding).
  return clip ? ClipRRect(borderRadius: theme.radiusMd, child: img) : img;
}
