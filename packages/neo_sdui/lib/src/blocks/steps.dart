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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: theme.spaceMd),
          Expanded(child: _cell(theme, i + 1, items[i], numberTone)),
        ],
      ],
    );
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
  return Column(
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
}

/// The circular number badge for a horizontal step: the tone-colored digit in a
/// 24px ring. The ring/digit color are theme roles (via `toneColor`), never the
/// wire.
Widget _badge(NeoSduiTheme theme, int n, String tone) => Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.toneColor(tone).withValues(alpha: 0.4)),
      ),
      child: neoText(
        theme,
        '$n',
        theme.caption.copyWith(fontWeight: FontWeight.w600),
        tone: tone,
      ),
    );

Widget _item(NeoSduiScope scope, int n, Map<String, Object?> item, String numberTone) {
  final theme = scope.theme;
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
Widget? _stepImage(NeoSduiTheme theme, Map<String, Object?> item) {
  final url = item['image'];
  if (url is! String || url.isEmpty) return null;
  final r = item['ratio'];
  final ratio = (r is num && r > 0 && r.isFinite) ? r.toDouble() : _defaultImageRatio;
  return ClipRRect(
    borderRadius: theme.radiusMd,
    child: Image.network(
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
    ),
  );
}
